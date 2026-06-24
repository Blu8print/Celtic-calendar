import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/database.dart';
import '../engine/celtic_calendar.dart';
import '../services/google_calendar_service.dart';
import '../theme/app_theme.dart';
import '../theme/moon_settings_notifier.dart';
import '../theme/sky_settings_notifier.dart';
import '../theme/theme_notifier.dart';
import 'onboarding_screen.dart';

/// Settings screen: Google account, sync status, and calendar system selector.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTextStyles.cinzelDeco(size: 16, color: c.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const _GoogleAccountSection(),
          const SizedBox(height: 24),
          const _AppearanceSection(),
          const SizedBox(height: 24),
          const _MoonSection(),
          const SizedBox(height: 24),
          const _SkySection(),
          const SizedBox(height: 24),
          const _DangerZoneSection(),
          const SizedBox(height: 24),
          const _SupportSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Google account & sync ────────────────────────────────────────────────────

class _GoogleAccountSection extends StatelessWidget {
  const _GoogleAccountSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<GoogleCalendarService>(
      builder: (context, gcal, _) {
        final c = context.colors;
        return _Section(
          title: 'Google Calendar',
          children: [
            if (!gcal.isSignedIn) ...[
              Text(
                'Sign in to sync events with your Google Calendar.\n'
                'No data passes through any intermediate server.',
                style: AppTextStyles.imFell(size: 13, color: c.text),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: gcal.isSigningIn ? null : gcal.signIn,
                icon: gcal.isSigningIn
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: c.gold,
                        ),
                      )
                    : const Icon(Icons.login, size: 16),
                label: Text(
                  gcal.isSigningIn ? 'Signing in…' : 'Sign in with Google',
                ),
              ),
              if (gcal.lastError != null) ...[
                const SizedBox(height: 10),
                _GcalErrorBox(message: gcal.lastError!),
              ],
            ] else ...[
              _InfoRow(label: 'Signed in as', value: gcal.userEmail ?? ''),
              const SizedBox(height: 12),
              Divider(color: c.muted, height: 1),
              const SizedBox(height: 12),

              // ── Connection status badge ───────────────────────────────────
              _SyncStatusBadge(gcal: gcal, relativeTime: _relativeTime),
              const SizedBox(height: 10),

              // ── Celtic year scope ─────────────────────────────────────────
              _CelticYearScope(),
              const SizedBox(height: 14),

              // ── Sync action ──────────────────────────────────────────────
              if (gcal.isSyncing)
                MergeSemantics(
                  child: Row(
                    children: [
                      SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: c.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Syncing with Google Calendar…',
                        style: AppTextStyles.cinzel(size: 12, color: c.text),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => gcal.syncYear(celticYearOf(DateTime.now())),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync now'),
                ),

              if (gcal.lastError != null) ...[
                const SizedBox(height: 10),
                _GcalErrorBox(message: gcal.lastError!),
              ],

              const SizedBox(height: 14),
              TextButton(
                onPressed: gcal.signOut,
                child: Text(
                  'Sign out',
                  style: AppTextStyles.cinzel(size: 12, color: Colors.redAccent.shade100),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static final _timeFmt = DateFormat('d MMM \'at\' HH:mm');

  String _relativeTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    final today = DateTime(now.year, now.month, now.day);
    final syncDay = DateTime(dt.year, dt.month, dt.day);
    if (syncDay == today) return 'Today at ${DateFormat('HH:mm').format(dt)}';
    return _timeFmt.format(dt);
  }
}

// ─── Sync status badge ────────────────────────────────────────────────────────

class _SyncStatusBadge extends StatelessWidget {
  final GoogleCalendarService gcal;
  final String Function(DateTime?) relativeTime;

  const _SyncStatusBadge({required this.gcal, required this.relativeTime});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color dotColor;
    final String label;

    if (gcal.lastSyncSuccess == null) {
      dotColor = c.dim;
      label = 'Never synced';
    } else if (gcal.lastSyncSuccess == true) {
      final count     = gcal.lastSyncCount;
      final failCount = gcal.lastPushFailCount;
      if (failCount > 0) {
        dotColor = const Color(0xffe8a84c); // amber — partial success
        label = 'Connected · ${relativeTime(gcal.lastSyncTime)} · '
            '$count pulled · $failCount push failure${failCount == 1 ? '' : 's'}';
      } else {
        dotColor = const Color(0xff4caf72); // forest green — full success
        label = 'Connected · ${relativeTime(gcal.lastSyncTime)} · '
            '$count event${count == 1 ? '' : 's'}';
      }
    } else {
      dotColor = Colors.redAccent;
      label = 'Sync failed · ${relativeTime(gcal.lastSyncTime)}';
    }

    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.cinzel(size: 12, color: c.text),
          ),
        ),
      ],
    );
  }
}

// ─── Celtic year scope label ──────────────────────────────────────────────────

class _CelticYearScope extends StatelessWidget {
  const _CelticYearScope();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final year = celticYearOf(now);
    return Text(
      'Syncing Celtic year $year (Dec 24 $year – Dec 23 ${year + 1})',
      style: AppTextStyles.imFell(size: 12, color: c.text, italic: true),
    );
  }
}

// ─── Calendar system selector (UI stub) ──────────────────────────────────────


// --- Appearance (theme toggle) ---

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final notifier = context.watch<ThemeNotifier>();
    return _Section(
      title: 'Appearance',
      children: [
        Row(
          children: [
            _ThemeChip(
              label: 'Light',
              icon: Icons.light_mode_outlined,
              isSelected: notifier.isLight,
              onTap: () => notifier.setLight(true),
            ),
            const SizedBox(width: 10),
            _ThemeChip(
              label: 'Dark',
              icon: Icons.dark_mode_outlined,
              isSelected: !notifier.isLight,
              onTap: () => notifier.setLight(false),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choose the look that suits you best.',
          style: AppTextStyles.imFell(size: 12, color: c.text, italic: true),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? c.surface2 : c.surface,
              border: Border.all(color: isSelected ? c.gold : c.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isSelected ? c.gold : c.dim),
                const SizedBox(width: 6),
                Text(label,
                    style: AppTextStyles.cinzel(
                        size: 12, color: isSelected ? c.gold : c.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared layout helpers ────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTextStyles.cinzel(
            size: 12,
            color: c.text,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Divider(color: c.muted, height: 1),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

// ─── Moon Phases ──────────────────────────────────────────────────────────────

class _MoonSection extends StatelessWidget {
  const _MoonSection();

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final settings = context.watch<MoonSettingsNotifier>();
    return _Section(
      title: 'Moon Phases',
      children: [
        _ToggleRow(
          label: 'Show full moons in month view',
          value: settings.showFullMoons,
          onChanged: settings.setShowFullMoons,
          colors: c,
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: 'Show new moons in month view',
          value: settings.showNewMoons,
          onChanged: settings.setShowNewMoons,
          colors: c,
        ),
      ],
    );
  }
}

// ─── Sky / Astronomical panel ─────────────────────────────────────────────────

class _SkySection extends StatelessWidget {
  const _SkySection();

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final settings = context.watch<SkySettingsNotifier>();
    return _Section(
      title: 'Sky Panel',
      children: [
        _ToggleRow(
          label: 'Moon phase & illumination',
          value: settings.showMoonPhase,
          onChanged: settings.setShowMoonPhase,
          colors: c,
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: 'Zodiac sign',
          value: settings.showZodiac,
          onChanged: settings.setShowZodiac,
          colors: c,
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: 'Sowing indicator',
          value: settings.showBiodynamic,
          onChanged: settings.setShowBiodynamic,
          colors: c,
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: 'Sunrise & sunset times',
          value: settings.showSunTimes,
          onChanged: settings.setShowSunTimes,
          colors: c,
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: 'Clock & solar time',
          value: settings.showClocks,
          onChanged: settings.setShowClocks,
          colors: c,
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: 'Moon distance',
          value: settings.showMoonDistance,
          onChanged: settings.setShowMoonDistance,
          colors: c,
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: 'Next solar event',
          value: settings.showSolarEvent,
          onChanged: settings.setShowSolarEvent,
          colors: c,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _requestAndStoreLocation(context),
          icon: Icon(Icons.my_location_outlined, size: 14, color: c.text),
          label: Text(
            'Update location',
            style: AppTextStyles.cinzel(size: 12, color: c.text),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
        ),
        Text(
          'Used only for sunrise and sunset. No background location access.',
          style: AppTextStyles.imFell(size: 12, color: c.text, italic: true),
        ),
      ],
    );
  }

  Future<void> _requestAndStoreLocation(BuildContext context) async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permission denied.',
              style: AppTextStyles.imFell(
                  size: 13, color: context.read<AppColors>().text),
            ),
            backgroundColor: context.read<AppColors>().surface2,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (context.mounted) {
        await context.read<SkySettingsNotifier>().updateLocation(
          pos.latitude,
          pos.longitude,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location updated.',
              style: AppTextStyles.imFell(
                  size: 13, color: context.read<AppColors>().text),
            ),
            backgroundColor: context.read<AppColors>().surface2,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Location request timed out or failed — fail silently.
    }
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  final AppColors colors;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.cinzel(size: 12, color: c.text)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.gold,
            activeTrackColor: c.gold.withValues(alpha: 0.35),
            inactiveThumbColor: c.dim,
            inactiveTrackColor: c.border,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Text(label, style: AppTextStyles.cinzel(size: 12, color: c.text)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.imFell(size: 13, color: c.text),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Gcal error box ───────────────────────────────────────────────────────────

class _GcalErrorBox extends StatelessWidget {
  final String message;
  const _GcalErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.imFell(size: 13, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Support / About ─────────────────────────────────────────────────────────

class _SupportSection extends StatelessWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Section(
      title: 'Support',
      children: [
        InkWell(
          onTap: () async {
            final uri = Uri.parse('mailto:support@blu8print.com');
            if (await canLaunchUrl(uri)) launchUrl(uri);
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.mail_outline, size: 16, color: c.text),
                const SizedBox(width: 10),
                Text(
                  'support@blu8print.com',
                  style: AppTextStyles.cinzel(size: 13, color: c.gold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Questions, feedback, or bug reports — we\'d love to hear from you.',
          style: AppTextStyles.imFell(size: 12, color: c.text, italic: true),
        ),
      ],
    );
  }
}

// ─── Danger zone ──────────────────────────────────────────────────────────────

class _DangerZoneSection extends StatelessWidget {
  const _DangerZoneSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Section(
      title: 'Danger Zone',
      children: [
        OutlinedButton.icon(
          onPressed: () => _confirmReset(context),
          icon: const Icon(Icons.delete_forever_outlined, size: 16, color: Colors.redAccent),
          label: Text(
            'Reset App & Clear All Data',
            style: AppTextStyles.cinzel(size: 13, color: Colors.redAccent),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            alignment: Alignment.centerLeft,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Deletes all events and resets all settings. Cannot be undone.',
          style: AppTextStyles.imFell(size: 12, color: c.text, italic: true),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          title: Text(
            'Reset App?',
            style: AppTextStyles.cinzelDeco(size: 15, color: c.text),
          ),
          content: Text(
            'This will permanently delete all your events and sign you out '
            'of Google Calendar. This cannot be undone.',
            style: AppTextStyles.imFell(size: 13, color: c.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.cinzel(size: 12, color: c.text)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Reset',
                  style: AppTextStyles.cinzel(
                      size: 12, color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final gcal  = context.read<GoogleCalendarService>();
    final db    = context.read<AppDatabase>();
    final moon  = context.read<MoonSettingsNotifier>();
    final sky   = context.read<SkySettingsNotifier>();
    final theme = context.read<ThemeNotifier>();

    if (gcal.isSignedIn) await gcal.signOut();
    await db.eventsDao.deleteAllEvents();
    await moon.setShowFullMoons(true);
    await moon.setShowNewMoons(false);
    await sky.setShowBiodynamic(true);
    await sky.setShowSunTimes(true);
    await theme.setLight(true);

    await sky.clearLocation();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', false);

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }
}
