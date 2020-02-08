import 'dart:html';

// web本地存储
class PlatformLocalStorage {
  Storage webStorage = window.localStorage;

  static PlatformLocalStorage _instance;
  static Future<PlatformLocalStorage> _getInstance() async {
    if (PlatformLocalStorage._instance == null) {
      PlatformLocalStorage._instance = new PlatformLocalStorage();
    }
    return PlatformLocalStorage._instance;
  }

  static Future<String> getItem(String name) async {
    return (await PlatformLocalStorage._getInstance())._getItem(name);
  }

  static setItem(String name, String value) async {
    (await PlatformLocalStorage._getInstance())._setItem(name, value);
  }

  _setItem(String name, String value) {
    this.webStorage[name] = value;
  }

  _getItem(String name) {
    return this.webStorage[name];
  }
}