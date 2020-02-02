import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

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

// 本地存储
/* v1
 * big Map
 * 
 * v2
 * (keyslen#[key,start,end]*)
 * (value value value newValue) addByGap or addByEnd
 * checkValid?
 */
class LocalStorage{
  String storageFilePath;
  File storageFile;
  Map storageJson;

  static LocalStorage _instance; 
  static Future<LocalStorage> _getInstance() async {
    if (LocalStorage._instance == null) {
      LocalStorage._instance = new LocalStorage();
      await LocalStorage._instance.init();
    }
    return LocalStorage._instance;
  }
  static Future<dynamic> getItem(String name) async {
    return (await LocalStorage._getInstance())._getItem(name); 
  }
  static setItem(String name,dynamic value) async {
    (await LocalStorage._getInstance())._setItem(name,value); 
  }
  
  init() async {
    this.storageFilePath = (await getApplicationDocumentsDirectory()).path + '/localStorage.json';
    this.storageFile = File(this.storageFilePath);
    if (!this.storageFile.existsSync()) {
      this.storageFile.createSync();
      this.storageFile.writeAsStringSync('{}');
    }
    Map sjson;
    try {
      sjson = jsonDecode(this.storageFile.readAsStringSync());
      if (sjson == null) throw '';
    } catch (e) {
      this.storageFile.writeAsStringSync('{}');
      sjson = {};
    }
    this.storageJson = sjson;
  }

  _setItem(String name,dynamic value) {
    this.storageJson[name] = value;
    this.storageFile.writeAsStringSync(jsonEncode(this.storageJson));
  }

  _getItem(String name) {
    return this.storageJson[name];
  }

}


