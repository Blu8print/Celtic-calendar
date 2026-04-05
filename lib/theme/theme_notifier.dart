import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists and exposes the user's light/dark theme preference.
/// Light is the default.
class ThemeNotifier extends ChangeNotifier {
  static const _kKey = 'app_theme';
  final _storage = const FlutterSecureStorage();

  bool _isLight = true;
  bool get isLight => _isLight;

  ThemeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _kKey);
    final isLight = value != 'dark'; // default true if unset
    if (isLight != _isLight) {
      _isLight = isLight;
      notifyListeners();
    }
  }

  Future<void> setLight(bool v) async {
    if (_isLight == v) return;
    _isLight = v;
    await _storage.write(key: _kKey, value: v ? 'light' : 'dark');
    notifyListeners();
  }
}
