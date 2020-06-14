import './utils.dart';
import './cpackage.dart';
import './default_msg_processor.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

const JS_WS_CLIENT_TYPE = 'js-websocket';
const JS_WS_CLIENT_VERSION = '0.0.1';
const DEFAULT_MAX_RECONNECT_ATTEMPTS = 10;

const RES_OK = 200;
const RES_FAIL = 500;
const RES_OLD_CLIENT = 501;

class Pomelo extends EventEmitter {
  WebSocketChannel wsSocket;

  Completer initCpl;
  Completer disconnectCpl;

  // 握手数据
  Map handshakeBody = {
    'sys': {
      'type': JS_WS_CLIENT_TYPE,
      'version': JS_WS_CLIENT_VERSION,
      'rsa': {},
    },
    'user': {}
  };

  // 心跳机制
  Duration heartbeatSendMs;
  Timer heartbeatSendTimer;
  Duration heartbeatReviceTimeoutMs;
  Timer heartbeatReviceTimeoutTimer;
  int heartbeatReviceTimeoutNext;

  //
  int reqId = 0;
  Map<int, String> reqRouteMap = {};
  Map<int, Completer> reqCpls = {};


  // 重连机制
  bool isReconnect = false;
  int reconnectAttempts = 0;
  Duration reconnectDelay = Duration(milliseconds: 5000);
  Timer reconnectTimer;

  String url;
  // paramsMap
  String host;
  int port;
  bool ssl;
  Map user;
  bool encrypt;
  bool tryReconnect;
  int maxReconnectAttempts;
  MsgProcessor msgProcessor;
  Function handshakeCb;

  // debug日志
  bool debug;
  List<String> debugLogList = [];

  /* [params] 
   * host,port,ssl,
   * msgProcessor(encode,decode), 数据包处理器
   * handshakeCallback, 握手回调
   * user,
   * reconnect,maxReconnectAttempts 重连
   * encrypt, 消息rsa加密传输 (暂不支持)
   * debug, 调试模式，输出日志
   */
  init(
      {String host,
      int port,
      bool ssl,
      MsgProcessor msgProcessor,
      Function handshakeCallback,
      Map user,
      bool encrypt,
      bool reconnect,
      int maxReconnectAttempts,
      bool debug}) async {
    initCpl = new Completer();

    this.debug = debug ?? false;
    this.host = host;
    this.port = port;
    this.ssl = ssl != null ? ssl : false;
    this.url = '';

    if (!this.ssl) {
      this.url = 'ws://' + this.host;
    } else {
      this.url = 'wss://' + this.host;
    }
    if (this.port != null) {
      this.url += ':' + this.port.toString();
    }

    this.encrypt = encrypt != null ? encrypt : false;
    if (this.encrypt) {
      throw 'Not yet Support params [encrypt]!';
    }

    this.msgProcessor =
        msgProcessor == null ? new DefaultMsgProcessor() : msgProcessor;

    this.handshakeCb = handshakeCallback;
    this.user = this.handshakeBody['user'] = user;
    this.tryReconnect = reconnect != null ? reconnect : false;
    this.maxReconnectAttempts = maxReconnectAttempts != null
        ? maxReconnectAttempts
        : DEFAULT_MAX_RECONNECT_ATTEMPTS;

    // 扩展消息握手包数据
    Map handshakeBodyExtend = await this.msgProcessor.handshakeExtend();
    this.handshakeBody.addEntries(handshakeBodyExtend.entries);

    this.connect();

    return initCpl.future;
  }

  connect() async {
    printDebugLog('connect to ' + url);

    if (this.wsSocket != null) {
      throw 'the current socket is holdin';
    }

    void onopen() {
      if (this.isReconnect) {
        this.emitEvent('SocketReconnectEvent', null);
        // reset
        this.isReconnect = false;
        this.reconnectAttempts = 0;
        this.reconnectDelay = Duration(milliseconds: 5000);
        if (this.reconnectTimer != null) {
          this.reconnectTimer.cancel();
          this.reconnectTimer = null;
        }
      }

      this.send(Cpackage.byEncode(CpackageType.HANDSHAKE,
              Utils.strencode(jsonEncode(this.handshakeBody)))
          .cpackageBuffer);
    }

    void onmessage(data) {
      data = List<int>.from(data);
      this.processPackage(Cpackage.decodeAll(data));
      if (heartbeatReviceTimeoutMs != null &&
          heartbeatReviceTimeoutMs.inMilliseconds > 0) {
        heartbeatReviceTimeoutNext = DateTime.now().millisecondsSinceEpoch +
            heartbeatReviceTimeoutMs.inMilliseconds;
      }
    }

    void onerror(e) {
      this.emitEvent('SocketErrorEvent', null);
      printDebugLog(e);
    }

    void onclose() {
      printDebugLog('socket close');
      this.wsSocket = null;
      this.emitEvent('SocketCloseEvent', null);

      // 完成断开连接
      if (disconnectCpl != null && (!disconnectCpl.isCompleted)) {
        disconnectCpl.complete();
      }

      // 是否为初始化失败
      if (initCpl != null && (!initCpl.isCompleted)) {
        initCpl.complete(false);
      } else {
        if (this.tryReconnect &&
            this.reconnectAttempts < this.maxReconnectAttempts) {
          this.isReconnect = true;
          this.reconnectAttempts++;
          this.reconnectTimer = new Timer(this.reconnectDelay, () {
            this.connect();
          });
          this.reconnectDelay *= 2;
        }
      }
    }

    try {
      this.wsSocket = WebSocketChannel.connect(Uri.parse(this.url));
      this.wsSocket.stream.listen(onmessage,
          onError: onerror, onDone: onclose, cancelOnError: false);
      onopen();  
    } catch (e) {
      onclose();
      printDebugLog(e);
    }
  }

  disconnect() async {
    disconnectCpl = new Completer();
    if (this.wsSocket != null) {
      await this.wsSocket.sink.close();
      this.wsSocket = null;
    }

    if (this.heartbeatSendTimer != null) {
      this.heartbeatSendTimer.cancel();
      this.heartbeatSendTimer = null;
    }
    if (this.heartbeatReviceTimeoutTimer != null) {
      this.heartbeatReviceTimeoutTimer.cancel();
      this.heartbeatReviceTimeoutTimer = null;
    }
    return disconnectCpl.future;
  }

  request(String route, Map body) async {
    this.reqId++;
    // sendMessage
    // if(useCrypto) {
    //   msg = JSON.stringify(msg);
    //   var sig = rsa.signString(msg, "sha256");
    //   msg = JSON.parse(msg);
    //   msg['__crypto__'] = sig;
    // }

    List<int> bodyBuffer = this.msgProcessor.encodeHandle(reqId, route, body);
    this.send(Cpackage.byEncode(CpackageType.DATA, bodyBuffer).cpackageBuffer);

    this.reqRouteMap[this.reqId] = route;
    this.reqCpls[this.reqId] = new Completer();
    return this.reqCpls[this.reqId].future;
  }

  notify(String route, Map body) {
    List<int> bodyBuffer = this.msgProcessor.encodeHandle(0, route, body);
    this.send(Cpackage.byEncode(CpackageType.DATA, bodyBuffer).cpackageBuffer);
  }

  send(List<int> buffer) {
    this.wsSocket.sink.add(Uint8List.fromList(buffer));
  }

  // 处理各package type
  handshakeHandle(Map data) {
    if (data['code'] == RES_OLD_CLIENT) {
      this.emitEvent('ErrorEvent', null);
      return;
    }
    if (data['code'] != RES_OK) {
      this.emitEvent('ErrorEvent', null);
      return;
    }
    // handshakeInit
    if (data['sys'] != null && data['sys']['heartbeat'] != null) {
      int sysheartbeat = data['sys']['heartbeat'] * 1000;
      this.heartbeatSendMs = Duration(milliseconds: sysheartbeat);
      this.heartbeatReviceTimeoutMs = Duration(milliseconds: sysheartbeat * 2);
    } else {
      this.heartbeatSendTimer = null;
      this.heartbeatReviceTimeoutTimer = null;
    }

    

    this.msgProcessor.handshakeInit(data,);
    if (this.handshakeCb != null) {
      this.handshakeCb(data['user']);
    }

    this.send(
        Cpackage.byEncode(CpackageType.HANDSHAKE_ACK, null).cpackageBuffer);
    if (initCpl != null && (!initCpl.isCompleted)) {
      initCpl.complete(true);
    }
  }

  heartbeatHandle() {
    if (heartbeatSendMs == null || heartbeatSendMs.inMilliseconds == 0) {
      // no heartbeat
      return;
    }

    if (heartbeatReviceTimeoutTimer != null) {
      heartbeatReviceTimeoutTimer.cancel();
      heartbeatReviceTimeoutTimer = null;
    }

    if (heartbeatSendTimer != null) {
      // already in a heartbeat interval
      return;
    }

    heartbeatSendTimer = new Timer(heartbeatSendMs, () {
      heartbeatSendTimer = null;
      this.send(Cpackage.byEncode(CpackageType.HEARTBEAT, null).cpackageBuffer);

      heartbeatReviceTimeoutNext = DateTime.now().millisecondsSinceEpoch +
          heartbeatReviceTimeoutMs.inMilliseconds;
      heartbeatReviceTimeoutTimer =
          new Timer(heartbeatReviceTimeoutMs, heartbeatReviceTimeoutCb);
    });
  }

  datapkgHandle(Map data) {
    processMessage(data);
  }

  kickpkgHandle(Map data) {
    this.emitEvent('PassiveKickEvent', null);
  }

  // 包处理
  processPackage(List<Cpackage> pkgList) {
    for (Cpackage pkg in pkgList) {
      printDebugLog(pkg.type);

      switch (pkg.type) {
        case CpackageType.HANDSHAKE:
          Map body = jsonDecode(Utils.strdecode(pkg.bodyBuffer));
          this.handshakeHandle(body);
          printDebugLog(body);
          break;
        case CpackageType.HEARTBEAT:
          this.heartbeatHandle();
          break;
        case CpackageType.DATA:
          Map body = this.msgProcessor.decodeHandle(pkg.bodyBuffer);
          this.datapkgHandle(body);
          break;
        case CpackageType.KICK:
          Map body = jsonDecode(Utils.strdecode(pkg.bodyBuffer));
          this.kickpkgHandle(body);
          printDebugLog(body);
          break;
        default:
      }
    }
  }

  processMessage(Map data) {
    if (data['id'] == 0) {
      // server push message
      this.emitEvent(data['route'], data['body']);
      return;
    }
    String route = this.reqRouteMap[data['id']];
    if (route == null) {
      // 未知reqid
      return;
    }
    this.reqRouteMap.remove(data['id']);

    Completer cpl = this.reqCpls[data['id']];
    if (cpl != null) {
      this.reqCpls.remove(data['id']);
      cpl.complete(data['body']);
    }
  }

  //
  heartbeatReviceTimeoutCb() {
    int gap =
        heartbeatReviceTimeoutNext - DateTime.now().millisecondsSinceEpoch;
    if (gap > 100) {
      heartbeatReviceTimeoutTimer =
          Timer(heartbeatReviceTimeoutMs, heartbeatReviceTimeoutCb);
    } else {
      this.emitEvent('HeartbeatTimeoutEvent', null);
      this.disconnect();
    }
  }

  // 输出日志
  getDebugLog() {
    return debugLogList;
  }
  printDebugLog(o) {
    if (this.debug) {
      try {
        debugLogList.add(jsonEncode(o));
      }catch (e) {
        debugLogList.add(o.toString());
      }
      print(o);
    }
  }
}
