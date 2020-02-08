import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';


// adndroid本地存储
/* v1
 * big Map
 * 
 * v2
 * (keyslen#[key,start,end]*)
 * (value value value newValue) addByGap or addByEnd
 * checkValid?
 */

class PlatformLocalStorage {
  String storageFilePath;
  File storageFile;
  Map storageJson;

  static PlatformLocalStorage _instance;
  static Future<PlatformLocalStorage> _getInstance() async {
    if (PlatformLocalStorage._instance == null) {
      PlatformLocalStorage._instance = new PlatformLocalStorage();
      await PlatformLocalStorage._instance.init();
    }
    return PlatformLocalStorage._instance;
  }

  static Future<String> getItem(String name) async {
    return (await PlatformLocalStorage._getInstance())._getItem(name);
  }

  static setItem(String name, String value) async {
    (await PlatformLocalStorage._getInstance())._setItem(name, value);
  }

  init() async {
    const SJSON_VERSION = 'v1.0';
    Map sjson = {'__version': SJSON_VERSION};
    this.storageFilePath =
        (await getApplicationDocumentsDirectory()).path + '/localStorage.json';
    this.storageFile = File(this.storageFilePath);
    if (!this.storageFile.existsSync()) {
      this.storageFile.createSync();
      this.storageFile.writeAsStringSync(jsonEncode(sjson));
    }
    try {
      sjson = jsonDecode(this.storageFile.readAsStringSync());
      if (sjson == null) throw '';
      if (sjson['__version'] != SJSON_VERSION) throw '';
    } catch (e) {
      sjson = {'__version': SJSON_VERSION};
      this.storageFile.writeAsStringSync(jsonEncode(sjson));
    }
    this.storageJson = sjson;
  }

  _setItem(String name, String value) {
    this.storageJson[name] = value;
    this.storageFile.writeAsStringSync(jsonEncode(this.storageJson));
  }

  _getItem(String name) {
    return this.storageJson[name];
  }
}
