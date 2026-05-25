import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes Sky panel display settings.
/// If every toggle is off, [showSkyPanel] returns false and the strip is hidden.
class SkySettingsNotifier extends ChangeNotifier {
  static const _kMoonPhase    = 'sky_moon_phase';
  static const _kZodiac       = 'sky_zodiac';
  static const _kBiodynamic   = 'sky_biodynamic';
  static const _kSunTimes     = 'sky_sun_times';
  static const _kMoonDistance = 'sky_moon_distance';
  static const _kSolarEvent   = 'sky_solar_event';
  static const _kClocks       = 'sky_clocks';

  bool _showMoonPhase    = true;
  bool _showZodiac       = true;
  bool _showBiodynamic   = true;
  bool _showSunTimes     = true;
  bool _showMoonDistance = true;
  bool _showSolarEvent   = true;
  bool _showClocks       = true;

  bool get showMoonPhase    => _showMoonPhase;
  bool get showZodiac       => _showZodiac;
  bool get showBiodynamic   => _showBiodynamic;
  bool get showSunTimes     => _showSunTimes;
  bool get showMoonDistance => _showMoonDistance;
  bool get showSolarEvent   => _showSolarEvent;
  bool get showClocks       => _showClocks;

  /// True if at least one row is enabled; false hides the strip entirely.
  bool get showSkyPanel =>
      _showMoonPhase ||
      _showZodiac    ||
      _showBiodynamic ||
      _showSunTimes  ||
      _showMoonDistance ||
      _showSolarEvent ||
      _showClocks;

  SkySettingsNotifier() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _showMoonPhase    = p.getBool(_kMoonPhase)    ?? true;
    _showZodiac       = p.getBool(_kZodiac)        ?? true;
    _showBiodynamic   = p.getBool(_kBiodynamic)    ?? true;
    _showSunTimes     = p.getBool(_kSunTimes)      ?? true;
    _showMoonDistance = p.getBool(_kMoonDistance)  ?? true;
    _showSolarEvent   = p.getBool(_kSolarEvent)    ?? true;
    _showClocks       = p.getBool(_kClocks)        ?? true;
    notifyListeners();
  }

  Future<void> setShowMoonPhase(bool v) async {
    if (_showMoonPhase == v) return;
    _showMoonPhase = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMoonPhase, v);
  }

  Future<void> setShowZodiac(bool v) async {
    if (_showZodiac == v) return;
    _showZodiac = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kZodiac, v);
  }

  Future<void> setShowBiodynamic(bool v) async {
    if (_showBiodynamic == v) return;
    _showBiodynamic = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBiodynamic, v);
  }

  Future<void> setShowSunTimes(bool v) async {
    if (_showSunTimes == v) return;
    _showSunTimes = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSunTimes, v);
  }

  Future<void> setShowMoonDistance(bool v) async {
    if (_showMoonDistance == v) return;
    _showMoonDistance = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMoonDistance, v);
  }

  Future<void> setShowSolarEvent(bool v) async {
    if (_showSolarEvent == v) return;
    _showSolarEvent = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSolarEvent, v);
  }

  Future<void> setShowClocks(bool v) async {
    if (_showClocks == v) return;
    _showClocks = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kClocks, v);
  }
}
