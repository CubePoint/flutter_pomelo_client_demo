import 'dart:convert';

class Utils {
  static List<int> strencode(String str) {
    List<int> result = utf8.encode(str);
    return result;
  }
  static String strdecode(buffer) {
    String result = utf8.decode(buffer);
    return result;
  }
}


// 消息包处理器接口
abstract class MsgProcessor {
  // 扩展握手包数据
  Future<Map> handshakeExtend();
  // 接受到握手包回应
  void handshakeInit(Map data);
  List<int> encodeHandle(int reqId, String route, Map body);
  Map decodeHandle(List<int> buffer);
}

// 事件触发器
class EventEmitter{
  Map<String,List<Function>> pools = {};

  onEvent(String type,Function callback) {
    type = type.toLowerCase();
    if (this.pools[type] == null)
      this.pools[type] = [];
    this.pools[type].add(callback);
  }
  emitEvent(String type,dynamic data) {
    type = type.toLowerCase();
    if (this.pools[type] == null) return;
    this.pools[type].forEach((cb){
      cb(data);
    });
  }
}
