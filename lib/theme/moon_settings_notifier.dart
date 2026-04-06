import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes moon phase display settings.
/// Defaults: full moons shown, new moons hidden.
class MoonSettingsNotifier extends ChangeNotifier {
  static const _kFullMoons = 'show_full_moons';
  static const _kNewMoons  = 'show_new_moons';

  bool _showFullMoons = true;
  bool _showNewMoons  = false;

  bool get showFullMoons => _showFullMoons;
  bool get showNewMoons  => _showNewMoons;

  MoonSettingsNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final full = prefs.getBool(_kFullMoons) ?? true;
    final newM = prefs.getBool(_kNewMoons)  ?? false;
    if (full != _showFullMoons || newM != _showNewMoons) {
      _showFullMoons = full;
      _showNewMoons  = newM;
      notifyListeners();
    }
  }

  Future<void> setShowFullMoons(bool v) async {
    if (_showFullMoons == v) return;
    _showFullMoons = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFullMoons, v);
  }

  Future<void> setShowNewMoons(bool v) async {
    if (_showNewMoons == v) return;
    _showNewMoons = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNewMoons, v);
  }
}
