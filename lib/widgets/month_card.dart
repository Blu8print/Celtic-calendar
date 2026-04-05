import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';

class UpcomingEvent {
  final int celticDay;
  final DateTime gregorianDate;
  final String title;

  const UpcomingEvent({
    required this.celticDay,
    required this.gregorianDate,
    required this.title,
  });
}

class MonthCard extends StatelessWidget {
  final int? month;
  final int celticYear;
  final List<UpcomingEvent> upcomingEvents;
  final void Function(DateTime date)? onEventTap;

  const MonthCard({
    super.key,
    required this.celticYear,
    required this.month,
    this.upcomingEvents = const [],
    this.onEventTap,
  });

  static final _dateFmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    return month == null ? _buildYearDay(context) : _buildMonth(context, month!);
  }

  Widget _buildMonth(BuildContext context, int m) {
    final c = context.colors;
    final mo = celticMonths[m - 1];
    final dates = gregorianDatesForMonth(celticYear, m);
    final dateRange =
        '${_dateFmt.format(dates.first)} – ${_dateFmt.format(dates.last)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Month $m of 13',
              style: AppTextStyles.cinzel(
                size: 11,
                color: c.muted,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mo.name,
              style: AppTextStyles.cinzelDeco(
                size: 28,
                color: c.gold2,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'The ${mo.tree}'.toUpperCase(),
              style: AppTextStyles.cinzel(
                size: 11,
                color: c.muted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mo.keyword,
              style: AppTextStyles.imFell(
                size: 11,
                color: c.text.withValues(alpha: 0.7),
                italic: true,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateRange,
              style: AppTextStyles.cinzel(size: 10, color: c.dim),
            ),
          ],
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'UPCOMING',
                style: AppTextStyles.cinzel(
                  size: 9,
                  color: c.dim,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              if (upcomingEvents.isEmpty)
                Text(
                  'No events ahead',
                  style: AppTextStyles.imFell(
                    size: 11,
                    color: c.dim,
                    italic: true,
                  ),
                )
              else
                ...upcomingEvents.asMap().entries.map((entry) {
                  final isNearest = entry.key == 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: _EventCard(
                      event: entry.value,
                      isNearest: isNearest,
                      onTap: () => onEventTap?.call(entry.value.gregorianDate),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYearDay(BuildContext context) {
    final c = context.colors;
    final yd = yearDayDate(celticYear);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day out of time',
              style: AppTextStyles.cinzel(
                size: 11,
                color: c.muted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Year Day',
              style: AppTextStyles.cinzelDeco(size: 28, color: c.gold2),
            ),
            const SizedBox(height: 2),
            Text(
              'The Nameless Day'.toUpperCase(),
              style: AppTextStyles.cinzel(
                size: 11,
                color: c.muted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Between the worlds',
              style: AppTextStyles.imFell(
                size: 11,
                color: c.text.withValues(alpha: 0.7),
                italic: true,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _dateFmt.format(yd),
              style: AppTextStyles.cinzel(size: 10, color: c.dim),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final UpcomingEvent event;
  final bool isNearest;
  final VoidCallback onTap;

  static final _dateFmt = DateFormat('d MMM');

  const _EventCard({
    required this.event,
    required this.isNearest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accentColor = isNearest ? c.gold : c.muted;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 2, color: accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 5, 8, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day ${event.celticDay} · ${_dateFmt.format(event.gregorianDate)}',
                          style: AppTextStyles.cinzel(size: 10, color: c.muted),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          event.title,
                          style: AppTextStyles.imFell(size: 12, color: c.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
