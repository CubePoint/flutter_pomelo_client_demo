import './message.dart';
import './utils.dart';
import './localstorage.dart' show LocalStorage;

import 'dart:convert';

class DefaultMsgProcessor extends MsgProcessor {
  // protobuf消息协议
  String protoVersion = '';
  Map serverProtos = {};
  Map clientProtos = {};
  // 压缩路由字典
  String dictVersion = '';
  Map routeToCode = {};
  Map codeToRoute = {};

  @override
  Future<Map> handshakeExtend() async {
    Map handshakeBody = {
      'sys': {
        'protoVersion': '',
        'dictVersion': '',
      }
    };

    if (this.protoVersion.isEmpty) {
      String protoDataStr =  await LocalStorage.getItem('pomelo.protoData');
      Map protoData;
      if (protoDataStr != null) protoData = jsonDecode(protoDataStr);
      if (protoData != null) {
        this.protoVersion = protoData['version'] ?? this.protoVersion;
        this.serverProtos = protoData['server'] ?? this.serverProtos;
        this.clientProtos = protoData['client'] ?? this.clientProtos;
      }
    }
    handshakeBody['sys']['protoVersion'] = this.protoVersion;

    if (this.dictVersion.isEmpty) {
      String dictDataStr =  await LocalStorage.getItem('pomelo.dictData');
      Map dictData;
      if (dictDataStr != null) dictData = jsonDecode(dictDataStr);
      if (dictData != null) {
        this.dictVersion = dictData['version'] ?? this.dictVersion;
        this.routeToCode = dictData['routeToCode'] ?? this.routeToCode;
        this.codeToRoute = dictData['codeToRoute'] ?? this.codeToRoute;
      }
    }
    handshakeBody['sys']['dictVersion'] = this.dictVersion;

    return handshakeBody;
  }

  @override
  void handshakeInit(Map data) {
  
    // protoInit
    if (data['sys'] != null && data['sys']['protos'] != null) {
      Map protoData = data['sys']['protos'];
      this.protoVersion = protoData['version'] ?? this.protoVersion;
      this.serverProtos = protoData['server'] ?? this.serverProtos;
      this.clientProtos = protoData['client'] ?? this.clientProtos;

      LocalStorage.setItem('pomelo.protoData', jsonEncode(protoData));

      if (this.serverProtos.isNotEmpty || this.clientProtos.isNotEmpty) {
        throw 'Not yet Support protobuf';
      }
    }

    // dictInit
    if (data['sys'] != null && data['sys']['routeToCode'] != null) {
      Map dictData = {
        'version': data['sys']['dictVersion'],
        'routeToCode': data['sys']['routeToCode'],
        'codeToRoute': data['sys']['codeToRoute'],
      };
      this.dictVersion = dictData['version'] ?? this.dictVersion;
      this.routeToCode = dictData['routeToCode'] ?? this.routeToCode;
      this.codeToRoute = dictData['codeToRoute'] ?? this.codeToRoute;

      LocalStorage.setItem('pomelo.dictData', jsonEncode(dictData));
    }
  }

  @override
  List<int> encodeHandle(int reqId, String route, Map body) {
    MessageType type = reqId > 0 ? MessageType.REQUEST : MessageType.NOTIFY;

    //compress message by protobuf
    // if(protobuf && clientProtos[route]) {
    //   msg = protobuf.encode(route, msg);
    // } else if(decodeIO_encoder && decodeIO_encoder.lookup(route)) {
    //   var Builder = decodeIO_encoder.build(route);
    //   msg = new Builder(msg).encodeNB();
    // } else {
    //   msg = Protocol.strencode(JSON.stringify(msg));
    // }
    List<int> bodyBuffer = Utils.strencode(jsonEncode(body));

    bool isCompressRoute = false;
    if (this.routeToCode != null && this.routeToCode[route] != null) {
      route = routeToCode[route].toString();
      isCompressRoute = true;
    }
    return Message.byEncode(
            reqId, type, isCompressRoute, route, bodyBuffer, false)
        .messageBuffer;
  }

  @override
  Map decodeHandle(List<int> buffer) {
    Message msg = Message.byDecode(buffer);
    String route = msg.route;
    dynamic body;

    if (msg.isCompressRoute) {
      int routeInt = num.parse(msg.route);
      if (codeToRoute == null || codeToRoute[routeInt] == null) {
        // 未知路由
        return null;
      }
      route = codeToRoute[routeInt];
    }
    body = jsonDecode(Utils.strdecode(msg.bodyBuffer));

    return {
      'id': msg.id,
      'type': msg.type,
      'isCompressRoute': msg.isCompressRoute,
      'route': route,
      'body': body,
      'isCompressGzip': msg.isCompressGzip
    };
  }
}
