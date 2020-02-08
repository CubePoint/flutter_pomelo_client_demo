import './weblocalstorage.dart'
    if (dart.library.io) './androidlocalstorage.dart';

class LocalStorage {
  static Future<String> getItem(String name) async {
    return await PlatformLocalStorage.getItem(name);
  }

  static setItem(String name, String value) async {
    await PlatformLocalStorage.setItem(name, value);
  }
}
