import 'package:shared_preferences/shared_preferences.dart';

const String kDefaultURL = 'https://searxng-railway-production-9bcc.up.railway.app';
const String kDefaultSafeSearch = '0'; // 0=Nada, 1=Moderada, 2=Rigorosa

class Settings {
  static const _keyURL = 'searxng_url';
  static const _keySafeSearch = 'safe_search';

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<String> getURL() async {
    final prefs = await _prefs;
    return prefs.getString(_keyURL) ?? kDefaultURL;
  }

  Future<void> setURL(String url) async {
    final prefs = await _prefs;
    await prefs.setString(_keyURL, url);
  }

  Future<String> getSafeSearch() async {
    final prefs = await _prefs;
    return prefs.getString(_keySafeSearch) ?? kDefaultSafeSearch;
  }

  Future<void> setSafeSearch(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_keySafeSearch, value);
  }
}
