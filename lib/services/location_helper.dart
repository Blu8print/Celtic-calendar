import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../theme/sky_settings_notifier.dart';

class LocationHelper {
  LocationHelper._();

  /// Requests location permission (if not already granted), fetches the
  /// current position, and saves it to [SkySettingsNotifier].
  /// No-ops silently if permission is denied or the position fetch fails.
  static Future<void> requestAndSave(BuildContext context) async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 15));
      if (!context.mounted) return;
      await context.read<SkySettingsNotifier>().updateLocation(
            pos.latitude,
            pos.longitude,
          );
      await HomeWidget.saveWidgetData<bool>('has_location', true);
      await HomeWidget.saveWidgetData<double>('sky_lon', pos.longitude);
      await HomeWidget.saveWidgetData<double>('user_longitude', pos.longitude);
      await HomeWidget.updateWidget(androidName: 'RootsDayWidget');
    } catch (e) {
      debugPrint('LocationHelper.requestAndSave failed: $e');
    }
  }
}
