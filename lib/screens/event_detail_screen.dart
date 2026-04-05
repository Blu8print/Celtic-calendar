import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../db/events_dao.dart';
import '../engine/celtic_calendar.dart';
import '../services/google_calendar_service.dart';
import '../theme/app_theme.dart';

// ─── Color palette (maps to Google Calendar colorIds) ─────────────────────────

const _kColorHexes = [
  '#c9a84c', '#e67c73', '#f4511e', '#33b679',
  '#039be5', '#7986cb', '#8e24aa', '#3f51b5',
];
const _kColorValues = [
  Color(0xFFc9a84c), Color(0xFFe67c73), Color(0xFFf4511e), Color(0xFF33b679),
  Color(0xFF039be5), Color(0xFF7986cb), Color(0xFF8e24aa), Color(0xFF3f51b5),
];

// Duration options: (minutes, display label)
const _kDurations = <(int, String)>[
  (15, '15 min'), (30, '30 min'), (45, '45 min'),
  (60, '1 h'), (90, '1.5 h'), (120, '2 h'), (180, '3 h'), (240, '4 h'),
];

// ─── Main screen ──────────────────────────────────────────────────────────────

/// Shows all events for a given day and allows adding / editing / deleting.
class EventDetailScreen extends StatelessWidget {
  final DateTime date;

  const EventDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dao = context.read<EventsDao>();
    final celticDate = gregorianToCeltic(date);
    final gFmt = DateFormat('EEEE, d MMMM yyyy');
    final dayNorm = DateTime(date.year, date.month, date.day);

    String celticLabel;
    if (celticDate.isLeapDay) {
      celticLabel = 'Leap Day · Celtic Year ${celticDate.celticYear}';
    } else if (celticDate.isYearDay) {
      celticLabel = 'Year Day · Celtic Year ${celticDate.celticYear}';
    } else {
      final mo = celticDate.monthData!;
      celticLabel =
          '${mo.name} · Day ${celticDate.day} · ${mo.tree} · ${mo.keyword}';
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              celticLabel,
              style: AppTextStyles.cinzel(size: 13, color: c.gold2),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              gFmt.format(date),
              style: AppTextStyles.imFell(size: 11, color: c.muted),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Event>>(
        stream: dao.watchEventsForDay(dayNorm),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          return CustomScrollView(
            slivers: [
              if (events.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _EventTile(
                      event: events[i],
                      onDelete: () => dao.deleteEvent(events[i].id),
                      onEdit: () => _showEventForm(context, dao, event: events[i]),
                    ),
                    childCount: events.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventForm(context, dao),
        backgroundColor: c.surface2,
        foregroundColor: c.gold,
        label: Text('Add Event', style: AppTextStyles.cinzel(size: 13, color: c.gold)),
        icon: Icon(Icons.add, color: c.gold),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showEventForm(
    BuildContext context,
    EventsDao dao, {
    Event? event,
  }) {
    final c = context.read<AppColors>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EventForm(
        date: date,
        dao: dao,
        existing: event,
        gcal: context.read<GoogleCalendarService>(),
      ),
    );
  }
}

// ─── Event tile ───────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final Event event;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _EventTile({
    required this.event,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _parseColor(event.color);

    // Build time range label.
    String? timeLabel;
    if (event.startMinutes != null) {
      final s = TimeOfDay(
        hour: event.startMinutes! ~/ 60,
        minute: event.startMinutes! % 60,
      );
      final endMin = event.startMinutes! + (event.durationMinutes ?? 60);
      final e = TimeOfDay(hour: (endMin ~/ 60) % 24, minute: endMin % 60);
      timeLabel = '${s.format(context)} – ${e.format(context)}';
    }

    // Attendee count.
    int attendeeCount = 0;
    if (event.attendees != null) {
      try {
        attendeeCount = (jsonDecode(event.attendees!) as List).length;
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + action buttons row.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: AppTextStyles.cinzel(size: 14, color: c.cream),
                  ),
                ),
                if (event.googleEventId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Icon(Icons.cloud_done_outlined, size: 15, color: c.muted),
                  ),
                _TileIconButton(icon: Icons.edit_outlined, onTap: onEdit),
                _TileIconButton(icon: Icons.delete_outline, onTap: () => _confirmDelete(context)),
              ],
            ),
            // Time.
            if (timeLabel != null) _TileDetail(Icons.access_time, timeLabel),
            // Description.
            if (event.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  event.description,
                  style: AppTextStyles.imFell(size: 12, color: c.muted),
                ),
              ),
            // Location.
            if (event.location != null)
              _LocationDetail(location: event.location!),
            // Attendees.
            if (attendeeCount > 0)
              _TileDetail(
                Icons.people_outline,
                '$attendeeCount attendee${attendeeCount == 1 ? '' : 's'}',
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final c = context.read<AppColors>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Delete event?', style: AppTextStyles.cinzel(size: 15, color: c.cream)),
        content: Text(event.title, style: AppTextStyles.imFell(size: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.cinzel(size: 12, color: c.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: Text('Delete', style: AppTextStyles.cinzel(size: 12, color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.dark.gold;
    }
  }
}

// Small icon button used inside the tile (zero padding, compact).
class _TileIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TileIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(icon, size: 18, color: c.muted),
      ),
    );
  }
}

// Icon + text row inside the tile.
class _TileDetail extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TileDetail(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: c.muted),
          const SizedBox(width: 5),
          Text(text, style: AppTextStyles.cinzel(size: 11, color: c.muted)),
        ],
      ),
    );
  }
}

// Location row with "open in maps" button.
class _LocationDetail extends StatelessWidget {
  final String location;
  const _LocationDetail({required this.location});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 13, color: c.muted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              location,
              style: AppTextStyles.imFell(size: 12, color: c.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(
                'https://maps.google.com/?q=${Uri.encodeComponent(location)}',
              );
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.open_in_new, size: 13, color: c.gold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Event form (add / edit) ──────────────────────────────────────────────────

class _EventForm extends StatefulWidget {
  final DateTime date;
  final EventsDao dao;
  final Event? existing;
  final GoogleCalendarService gcal;

  const _EventForm({
    required this.date,
    required this.dao,
    required this.gcal,
    this.existing,
  });

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();

  TimeOfDay? _startTime;
  int        _durationMinutes = 60;
  List<String> _attendees    = [];
  String     _color          = '#c9a84c';
  bool       _saving         = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text    = e.title;
      _descCtrl.text     = e.description;
      _locationCtrl.text = e.location ?? '';
      _color             = e.color;
      if (e.startMinutes != null) {
        _startTime       = TimeOfDay(hour: e.startMinutes! ~/ 60, minute: e.startMinutes! % 60);
        _durationMinutes = e.durationMinutes ?? 60;
      }
      if (e.attendees != null) {
        try { _attendees = List<String>.from(jsonDecode(e.attendees!)); } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _pickTime(BuildContext context) async {
    final c = context.read<AppColors>();
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: c.gold,
            onPrimary: c.bg,
            surface: c.surface2,
            onSurface: c.cream,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _startTime = picked);
  }

  void _addAttendee() {
    final email = _emailCtrl.text.trim();
    if (email.contains('@') && !_attendees.contains(email)) {
      setState(() {
        _attendees.add(email);
        _emailCtrl.clear();
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final celticDate = gregorianToCeltic(widget.date);
    final dayNorm    = DateTime(widget.date.year, widget.date.month, widget.date.day);

    final sm  = _startTime == null ? null : _startTime!.hour * 60 + _startTime!.minute;
    final dm  = _startTime == null ? null : _durationMinutes;
    final att = _attendees.isEmpty ? null : jsonEncode(_attendees);
    final loc = _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim();

    if (widget.existing == null) {
      await widget.dao.insertEvent(EventsCompanion(
        id:              Value(const Uuid().v4()),
        celticYear:      Value(celticDate.celticYear),
        celticMonth:     Value(celticDate.month),
        celticDay:       Value(celticDate.day),
        title:           Value(_titleCtrl.text.trim()),
        description:     Value(_descCtrl.text.trim()),
        color:           Value(_color),
        gregorianDate:   Value(dayNorm),
        startMinutes:    Value(sm),
        durationMinutes: Value(dm),
        attendees:       Value(att),
        location:        Value(loc),
      ));
    } else {
      await widget.dao.updateEvent(widget.existing!.copyWith(
        title:           _titleCtrl.text.trim(),
        description:     _descCtrl.text.trim(),
        color:           _color,
        updatedAt:       DateTime.now(),
        startMinutes:    Value(sm),
        durationMinutes: Value(dm),
        attendees:       Value(att),
        location:        Value(loc),
      ));
    }

    if (widget.gcal.isSignedIn) await widget.gcal.syncPendingEvents();
    if (mounted) Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isEdit = widget.existing != null;

    // Compute end time for display.
    TimeOfDay? endTime;
    if (_startTime != null) {
      final endMin = _startTime!.hour * 60 + _startTime!.minute + _durationMinutes;
      endTime = TimeOfDay(hour: (endMin ~/ 60) % 24, minute: endMin % 60);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Text(
            isEdit ? 'Edit Event' : 'New Event',
            style: AppTextStyles.cinzelDeco(size: 16, color: c.gold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // ── Title ───────────────────────────────────────────────────────
          TextField(
            controller: _titleCtrl,
            style: AppTextStyles.cinzel(size: 14, color: c.cream),
            decoration: const InputDecoration(labelText: 'Title'),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 10),

          // ── Description ─────────────────────────────────────────────────
          TextField(
            controller: _descCtrl,
            style: AppTextStyles.imFell(size: 13),
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          // ── Time ────────────────────────────────────────────────────────
          _FormLabel('Time'),
          _TimeRow(
            startTime: _startTime,
            onTap: () => _pickTime(context),
            onClear: () => setState(() => _startTime = null),
          ),
          if (_startTime != null) ...[
            const SizedBox(height: 8),
            _DurationRow(
              durationMinutes: _durationMinutes,
              endTime: endTime!,
              onChanged: (v) => setState(() => _durationMinutes = v),
            ),
          ],
          const SizedBox(height: 14),

          // ── Location ────────────────────────────────────────────────────
          _FormLabel('Location'),
          TextField(
            controller: _locationCtrl,
            style: AppTextStyles.imFell(size: 13, color: c.cream),
            decoration: InputDecoration(
              hintText: 'Add location',
              hintStyle: AppTextStyles.imFell(size: 13, color: c.dim),
              prefixIcon: Icon(Icons.place_outlined, size: 18, color: c.muted),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),

          // ── Invite ──────────────────────────────────────────────────────
          _FormLabel('Invite'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  style: AppTextStyles.imFell(size: 13, color: c.cream),
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    hintStyle: AppTextStyles.imFell(size: 13, color: c.dim),
                    prefixIcon: Icon(Icons.person_add_outlined, size: 18, color: c.muted),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _addAttendee(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _addAttendee,
                child: Text('Add', style: AppTextStyles.cinzel(size: 13, color: c.gold)),
              ),
            ],
          ),
          if (_attendees.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _attendees
                  .map((email) => _AttendeeChip(
                        email: email,
                        onRemove: () => setState(() => _attendees.remove(email)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),

          // ── Color ───────────────────────────────────────────────────────
          _FormLabel('Color'),
          const SizedBox(height: 8),
          _ColorPickerRow(
            selected: _color,
            onChanged: (hex) => setState(() => _color = hex),
          ),

          // ── Google sync note ─────────────────────────────────────────────
          if (widget.gcal.isSignedIn) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.cloud_done_outlined, size: 14, color: c.muted),
                const SizedBox(width: 6),
                Text(
                  'Will sync to Google Calendar',
                  style: AppTextStyles.cinzel(size: 11, color: c.dim),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // ── Save button ──────────────────────────────────────────────────
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.gold),
                  )
                : Text(isEdit ? 'Save Changes' : 'Add Event'),
          ),
        ],
      ),
    );
  }
}

// ─── Form sub-widgets ─────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.cinzel(size: 10, color: c.muted, letterSpacing: 1.5),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final TimeOfDay? startTime;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _TimeRow({required this.startTime, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (startTime == null) {
      return GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: c.muted),
            const SizedBox(width: 10),
            Text('All day', style: AppTextStyles.cinzel(size: 13, color: c.muted)),
            const SizedBox(width: 6),
            Text(
              '(tap to set time)',
              style: AppTextStyles.imFell(size: 11, color: c.dim, italic: true),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Icon(Icons.access_time, size: 18, color: c.gold),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onTap,
          child: Text(
            startTime!.format(context),
            style: AppTextStyles.cinzel(size: 14, color: c.cream),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onClear,
          child: Icon(Icons.close, size: 16, color: c.muted),
        ),
      ],
    );
  }
}

class _DurationRow extends StatelessWidget {
  final int durationMinutes;
  final TimeOfDay endTime;
  final ValueChanged<int> onChanged;

  const _DurationRow({
    required this.durationMinutes,
    required this.endTime,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 18, color: c.muted),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: _kDurations.any((d) => d.$1 == durationMinutes)
              ? durationMinutes
              : _kDurations.first.$1,
          dropdownColor: c.surface2,
          underline: const SizedBox(),
          style: AppTextStyles.cinzel(size: 13, color: c.cream),
          items: _kDurations
              .map((d) => DropdownMenuItem(value: d.$1, child: Text(d.$2)))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
        const SizedBox(width: 8),
        Text(
          '→ ends ${endTime.format(context)}',
          style: AppTextStyles.imFell(size: 12, color: c.muted),
        ),
      ],
    );
  }
}

class _AttendeeChip extends StatelessWidget {
  final String email;
  final VoidCallback onRemove;

  const _AttendeeChip({required this.email, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(email, style: AppTextStyles.imFell(size: 12, color: c.text)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: c.dim),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ColorPickerRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_kColorHexes.length, (i) {
        final isSelected = _kColorHexes[i] == selected;
        return GestureDetector(
          onTap: () => onChanged(_kColorHexes[i]),
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _kColorValues[i],
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        );
      }),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Text('☽', style: AppTextStyles.cinzel(size: 40, color: c.dim)),
          const SizedBox(height: 12),
          Text(
            'No events on this day',
            style: AppTextStyles.imFell(size: 14, color: c.muted, italic: true),
          ),
        ],
      ),
    );
  }
}
