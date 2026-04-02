import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../db/events_dao.dart';
import '../engine/celtic_calendar.dart';
import '../services/google_calendar_service.dart';
import '../theme/app_theme.dart';

/// Shows all events for a given day and allows adding / editing / deleting.
class EventDetailScreen extends StatelessWidget {
  final DateTime date;

  const EventDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              celticLabel,
              style: AppTextStyles.cinzel(size: 13, color: AppColors.gold2),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              gFmt.format(date),
              style: AppTextStyles.imFell(size: 11, color: AppColors.muted),
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
        backgroundColor: AppColors.surface2,
        foregroundColor: AppColors.gold,
        label: Text('Add Event', style: AppTextStyles.cinzel(size: 13, color: AppColors.gold)),
        icon: const Icon(Icons.add, color: AppColors.gold),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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
    final color = _parseColor(event.color);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        title: Text(
          event.title,
          style: AppTextStyles.cinzel(size: 14, color: AppColors.cream),
        ),
        subtitle: event.description.isNotEmpty
            ? Text(
                event.description,
                style: AppTextStyles.imFell(size: 12, color: AppColors.muted),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (event.googleEventId != null)
              const Icon(Icons.cloud_done_outlined, size: 16, color: AppColors.muted),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete event?', style: AppTextStyles.cinzel(size: 15, color: AppColors.cream)),
        content: Text(event.title, style: AppTextStyles.imFell(size: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.cinzel(size: 12, color: AppColors.muted)),
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
      return AppColors.gold;
    }
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
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _titleCtrl.text = widget.existing!.title;
      _descCtrl.text = widget.existing!.description;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final celticDate = gregorianToCeltic(widget.date);
    final dayNorm = DateTime(widget.date.year, widget.date.month, widget.date.day);

    if (widget.existing == null) {
      // Insert new event.
      final companion = EventsCompanion(
        id: Value(const Uuid().v4()),
        celticYear: Value(celticDate.celticYear),
        celticMonth: Value(celticDate.month),
        celticDay: Value(celticDate.day),
        title: Value(_titleCtrl.text.trim()),
        description: Value(_descCtrl.text.trim()),
        gregorianDate: Value(dayNorm),
      );
      await widget.dao.insertEvent(companion);
    } else {
      // Update existing event.
      final updated = widget.existing!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        updatedAt: DateTime.now(),
      );
      await widget.dao.updateEvent(updated);
    }

    // Auto-push to Google Calendar if signed in.
    // syncPendingEvents pushes any events with syncedToGoogle = false.
    if (widget.gcal.isSignedIn) {
      await widget.gcal.syncPendingEvents();
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEdit ? 'Edit Event' : 'New Event',
            style: AppTextStyles.cinzelDeco(size: 16, color: AppColors.gold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: AppTextStyles.cinzel(size: 14, color: AppColors.cream),
            decoration: const InputDecoration(labelText: 'Title'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            style: AppTextStyles.imFell(size: 13),
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (widget.gcal.isSignedIn) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.cloud_done_outlined, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(
                  'Will sync to Google Calendar',
                  style: AppTextStyles.cinzel(size: 11, color: AppColors.dim),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  )
                : Text(isEdit ? 'Save Changes' : 'Add Event'),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Text('☽', style: AppTextStyles.cinzel(size: 40, color: AppColors.dim)),
          const SizedBox(height: 12),
          Text(
            'No events on this day',
            style: AppTextStyles.imFell(size: 14, color: AppColors.muted, italic: true),
          ),
        ],
      ),
    );
  }
}
