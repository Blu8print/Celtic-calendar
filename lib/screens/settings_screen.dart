import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../engine/celtic_calendar.dart';
import '../services/google_calendar_service.dart';
import '../theme/app_theme.dart';
import '../theme/moon_settings_notifier.dart';
import '../theme/theme_notifier.dart';

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
          const _CalendarSystemSection(),
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
                style: AppTextStyles.imFell(size: 13, color: c.muted),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: gcal.signIn,
                icon: const Icon(Icons.login, size: 16),
                label: const Text('Sign in with Google'),
              ),
              if (gcal.lastError != null) ...[
                const SizedBox(height: 10),
                Container(
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
                          gcal.lastError!,
                          style: AppTextStyles.imFell(size: 11, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              _InfoRow(label: 'Signed in as', value: gcal.userEmail ?? ''),
              const SizedBox(height: 12),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 12),

              // ── Connection status badge ───────────────────────────────────
              _SyncStatusBadge(gcal: gcal, relativeTime: _relativeTime),
              const SizedBox(height: 10),

              // ── Celtic year scope ─────────────────────────────────────────
              _CelticYearScope(),
              const SizedBox(height: 14),

              // ── Sync action ──────────────────────────────────────────────
              if (gcal.isSyncing)
                Row(
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
                      style: AppTextStyles.cinzel(size: 12, color: c.muted),
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: () => gcal.syncYear(celticYearOf(DateTime.now())),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync now'),
                ),

              if (gcal.lastError != null) ...[
                const SizedBox(height: 10),
                Container(
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
                          gcal.lastError!,
                          style: AppTextStyles.imFell(size: 11, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
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
      dotColor = const Color(0xff4caf72); // forest green
      final count = gcal.lastSyncCount;
      label = 'Connected · ${relativeTime(gcal.lastSyncTime)} · '
          '$count event${count == 1 ? '' : 's'}';
    } else {
      dotColor = Colors.redAccent;
      label = 'Sync failed · ${relativeTime(gcal.lastSyncTime)}';
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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
    final start = year;      // Dec 24 of this year
    final end = year + 1;    // Dec 23 of next year
    return Text(
      'Syncing Celtic year $year  (Dec 24 $start – Dec 23 $end)',
      style: AppTextStyles.imFell(size: 11, color: c.dim, italic: true),
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
          style: AppTextStyles.imFell(size: 11, color: c.dim, italic: true),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }
}

// TODO: Implement actual IFC and other calendar system switching.
//       Each system should implement a CalendarSystem interface (see engine/).
class _CalendarSystemSection extends StatelessWidget {
  const _CalendarSystemSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Section(
      title: 'Calendar System',
      children: [
        _SystemChip(
          label: 'Celtic Tree (Beth-Luis-Nion)',
          isSelected: true,
          onTap: () {},
        ),
        const SizedBox(height: 6),
        _SystemChip(
          label: 'International Fixed Calendar',
          isSelected: false,
          onTap: () => _showComingSoon(context, 'International Fixed Calendar'),
        ),
        const SizedBox(height: 6),
        _SystemChip(
          label: 'Holocene Calendar',
          isSelected: false,
          onTap: () => _showComingSoon(context, 'Holocene Calendar'),
        ),
        const SizedBox(height: 8),
        Text(
          'Additional calendar systems coming in a future release.',
          style: AppTextStyles.imFell(size: 11, color: c.dim, italic: true),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String name) {
    final c = context.read<AppColors>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.surface2,
        content: Text(
          '$name — coming soon',
          style: AppTextStyles.imFell(size: 13, color: c.text),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SystemChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? c.surface2 : c.surface,
          border: Border.all(
            color: isSelected ? c.gold : c.border,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected ? c.gold : c.dim,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.cinzel(
                size: 13,
                color: isSelected ? c.gold : c.muted,
              ),
            ),
          ],
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
            size: 11,
            color: c.muted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Divider(color: c.border, height: 1),
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
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTextStyles.cinzel(size: 12, color: c.text)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: c.muted,
          inactiveTrackColor: c.border,
        ),
      ],
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
        Text(label, style: AppTextStyles.cinzel(size: 12, color: c.dim)),
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
