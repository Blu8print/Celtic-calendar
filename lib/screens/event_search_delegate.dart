import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../db/events_dao.dart';
import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';
import 'event_detail_screen.dart';

class EventSearchDelegate extends SearchDelegate<Event?> {
  final EventsDao dao;

  EventSearchDelegate({required this.dao})
      : super(searchFieldLabel: 'Search events…');

  @override
  ThemeData appBarTheme(BuildContext context) {
    final c = context.colors;
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        elevation: 0.5,
        shadowColor: c.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppTextStyles.imFell(size: 14, color: c.dim, italic: true),
        border: InputBorder.none,
      ),
      textTheme: Theme.of(context).textTheme.copyWith(
            titleLarge: AppTextStyles.cinzel(size: 14, color: c.text),
          ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    final c = context.colors;
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: Icon(Icons.clear, color: c.muted),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    final c = context.colors;
    return IconButton(
      icon: Icon(Icons.arrow_back, color: c.muted),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) return _emptyHint(context);
    return _results(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) return _emptyHint(context);
    return _results(context);
  }

  Widget _emptyHint(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      child: Center(
        child: Text(
          'Type to search events',
          style: AppTextStyles.imFell(size: 14, color: c.dim, italic: true),
        ),
      ),
    );
  }

  Widget _results(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      child: FutureBuilder<List<Event>>(
        future: dao.searchEvents(query.trim()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: c.gold));
          }
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return Center(
              child: Text(
                'No events found',
                style: AppTextStyles.imFell(size: 14, color: c.dim, italic: true),
              ),
            );
          }
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
            itemBuilder: (context, i) => _EventTile(
              event: results[i],
              onTap: () {
                close(context, null);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EventDetailScreen(date: results[i].gregorianDate),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final celtic = gregorianToCeltic(event.gregorianDate);
    final monthName = celtic.monthData?.name ?? 'Year Day';
    final celticLabel = celtic.month != null
        ? '$monthName ${celtic.day}'
        : monthName;
    final gregLabel =
        DateFormat('d MMM y').format(event.gregorianDate.toLocal());

    Color dotColor;
    try {
      dotColor = Color(
          int.parse('FF${event.color.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      dotColor = const Color(0xFFc9a84c);
    }

    return Material(
      color: c.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: AppTextStyles.cinzel(size: 13, color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$celticLabel  ·  $gregLabel',
                      style:
                          AppTextStyles.imFell(size: 11, color: c.muted, italic: true),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.dim, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
