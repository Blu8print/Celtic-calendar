import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../engine/celtic_calendar.dart';
import '../engine/celtic_festivals.dart';
import '../theme/app_theme.dart';

// Festival dot / bar colours
const _kFestivalFireColor  = Color(0xFFb07800); // warm gold
const _kFestivalSolarColor = Color(0xFF4a3080); // celestial purple

/// 7-column × 4-row grid of the 28 days in a Celtic month,
/// followed by an "Events this month" list.
class DayGrid extends StatelessWidget {
  final int celticYear;
  final int month;

  /// Map of Celtic day number → event color for days that have at least one event.
  final Map<int, Color> daysWithEvents;

  /// Map of Celtic day number → festival color (fire or solar).
  final Map<int, Color> daysWithFestivals;

  /// Map of Celtic day number → moon symbol ('🌕' / '🌑'), already filtered by settings.
  final Map<int, String> moonSymbols;

  /// Full month events (unfiltered) — used for the upcoming events list.
  final List<Event> events;

  /// Festivals that fall in this Celtic month — used for the upcoming list.
  final List<CelticFestival> festivalsThisMonth;

  /// Called when a day cell is tapped. Receives the Gregorian [DateTime].
  final void Function(DateTime date)? onDayTap;

  /// Called when a day cell is long-pressed. Receives the Gregorian [DateTime].
  final void Function(DateTime date)? onDayLongPress;

  /// Called when an event row in the list is tapped.
  final void Function(DateTime date)? onEventTap;

  static const _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  const DayGrid({
    super.key,
    required this.celticYear,
    required this.month,
    this.daysWithEvents        = const <int, Color>{},
    this.daysWithFestivals     = const <int, Color>{},
    this.moonSymbols           = const <int, String>{},
    this.events                = const [],
    this.festivalsThisMonth    = const [],
    this.onDayTap,
    this.onDayLongPress,
    this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final dates    = gregorianDatesForMonth(celticYear, month);
    final startDow = monthStartWeekday(celticYear);
    final today    = DateTime.now();
    final headers  = List.generate(7, (i) => _weekdays[(startDow + i) % 7]);

    // Build all items for this month — events + festivals.
    final monthFestivals = festivalsThisMonth
        .map((f) {
          final cd = gregorianToCeltic(f.gregorianDate);
          return _UpcomingItem.festival(f, cd.day ?? 1);
        })
        .toList();

    final allItems = [
      ...events.map((e) => _UpcomingItem.event(e)),
      ...monthFestivals,
    ];

    final now = DateTime.now();
    final upcoming = allItems.where((i) => !_isItemPast(i, now)).toList()
      ..sort((a, b) => _itemSortKey(a).compareTo(_itemSortKey(b)));
    final waned = allItems.where((i) => _isItemPast(i, now)).toList()
      ..sort((a, b) => _itemSortKey(b).compareTo(_itemSortKey(a)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Weekday header row ──────────────────────────────────────────
        Row(
          children: headers
              .map((wd) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(wd,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.cinzel(size: 9, color: c.dim)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),

        // ── 28-day grid ──────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 56,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
          ),
          itemCount: 28,
          itemBuilder: (context, index) {
            final celticDay = index + 1;
            final date = dates[index];
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;

            // Festivals first, then event — max 4 dots
            final dotColors = <Color>[
              if (daysWithFestivals.containsKey(celticDay))
                daysWithFestivals[celticDay]!,
              if (daysWithEvents.containsKey(celticDay))
                daysWithEvents[celticDay]!,
            ];

            return _DayCell(
              celticDay: celticDay,
              gregDate: date,
              isToday: isToday,
              dotColors: dotColors,
              moonSymbol: moonSymbols[celticDay],
              onTap: () => onDayTap?.call(date),
              onLongPress: () => onDayLongPress?.call(date),
            );
          },
        ),

        const SizedBox(height: 12),

        // ── Events this month ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section header
              Container(
                color: c.surface2,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                child: Text(
                  'EVENTS THIS MONTH',
                  style: AppTextStyles.cinzel(
                      size: 9,
                      color: c.dim,
                      letterSpacing: 1.0,
                      weight: FontWeight.w600),
                ),
              ),
              if (upcoming.isEmpty && waned.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('No events this month',
                      style: AppTextStyles.imFell(
                          size: 13, color: c.dim, italic: true)),
                )
              else ...[
                ...upcoming.map((item) => item.festival != null
                    ? _buildFestivalRow(context, c, item)
                    : _buildEventRow(context, c, item)),
                if (upcoming.isNotEmpty && waned.isNotEmpty)
                  Container(
                    color: c.surface2,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    child: Text(
                      'WANED',
                      style: AppTextStyles.cinzel(
                          size: 9,
                          color: c.dim,
                          letterSpacing: 1.0,
                          weight: FontWeight.w600),
                    ),
                  ),
                ...waned.map((item) => Opacity(
                      opacity: 0.5,
                      child: item.festival != null
                          ? _buildFestivalRow(context, c, item)
                          : _buildEventRow(context, c, item),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Event row ─────────────────────────────────────────────────────────────

  Widget _buildEventRow(
      BuildContext context, AppColors c, _UpcomingItem item) {
    final e   = item.event!;
    final col = _parseHex(e.color);
    final isAllDay = e.startMinutes == null;
    String timeStr;
    if (isAllDay) {
      timeStr = 'All day';
    } else {
      final sMin = e.startMinutes!;
      final eMin = sMin + (e.durationMinutes ?? 60);
      timeStr =
          '${(sMin ~/ 60).toString().padLeft(2, '0')}:${(sMin % 60).toString().padLeft(2, '0')}'
          '\u2013${(eMin ~/ 60).toString().padLeft(2, '0')}:${(eMin % 60).toString().padLeft(2, '0')}';
    }
    return InkWell(
      onTap: () => onEventTap?.call(e.gregorianDate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Day badge
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Text('${e.celticDay ?? ''}',
                      style: AppTextStyles.cinzel(
                          size: 15, weight: FontWeight.w700, color: c.muted)),
                  Text(DateFormat('d/M').format(e.gregorianDate),
                      style: AppTextStyles.cinzel(size: 8, color: c.dim)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Color bar
            Container(
              width: 3, height: 36,
              decoration: BoxDecoration(
                  color: col, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            // Title + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: AppTextStyles.imFell(size: 14, color: c.text),
                      overflow: TextOverflow.ellipsis),
                  Text(timeStr,
                      style: AppTextStyles.cinzel(size: 10, color: c.dim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Festival row (read-only) ───────────────────────────────────────────────

  Widget _buildFestivalRow(
      BuildContext context, AppColors c, _UpcomingItem item) {
    final f       = item.festival!;
    final barColor = f.type == FestivalType.fire
        ? _kFestivalFireColor
        : _kFestivalSolarColor;
    final gregDate = f.gregorianDate.toLocal();

    return InkWell(
      onTap: () => onEventTap?.call(f.gregorianDate.toLocal()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Day badge
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Text('${item.celticDay}',
                      style: AppTextStyles.cinzel(
                          size: 15, weight: FontWeight.w700, color: c.dim)),
                  Text(DateFormat('d/M').format(gregDate),
                      style: AppTextStyles.cinzel(size: 8, color: c.dim)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Color bar
            Container(
              width: 3, height: 36,
              decoration: BoxDecoration(
                  color: barColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            // Title + label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${f.symbol}  ${f.name}',
                      style: AppTextStyles.imFell(size: 14, color: c.dim),
                      overflow: TextOverflow.ellipsis),
                  Text('Celtic Festival',
                      style: AppTextStyles.cinzel(size: 10, color: c.dim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _UpcomingItem ─────────────────────────────────────────────────────────────

class _UpcomingItem {
  final int celticDay;
  final Event? event;
  final CelticFestival? festival;

  _UpcomingItem.event(Event e)
      : celticDay = e.celticDay ?? 0,
        event     = e,
        festival  = null;

  _UpcomingItem.festival(CelticFestival f, int day)
      : celticDay = day,
        event     = null,
        festival  = f;
}

// ── _DayCell ──────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int celticDay;
  final DateTime gregDate;
  final bool isToday;

  /// Dot colours shown below the day number. Festivals first, then event.
  /// Max 4 rendered. Empty = no dots.
  final List<Color> dotColors;

  /// Moon phase symbol shown in the top-right corner, or null if none.
  final String? moonSymbol;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _DayCell({
    required this.celticDay,
    required this.gregDate,
    required this.isToday,
    this.dotColors  = const [],
    this.moonSymbol,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final dayContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isToday
            ? Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: c.muted, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$celticDay',
                    style: AppTextStyles.cinzel(
                        size: 13,
                        weight: FontWeight.w700,
                        color: c.surface)),
              )
            : Text('$celticDay',
                style: AppTextStyles.cinzel(size: 13, color: c.text)),
        const SizedBox(height: 2),
        // Dot row — max 4 dots
        SizedBox(
          height: 6,
          child: dotColors.isEmpty
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dotColors.take(4).map((col) => Container(
                    width: 5, height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                        color: col, shape: BoxShape.circle),
                  )).toList(),
                ),
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? c.todayBg : null,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: moonSymbol != null
            ? Stack(
                children: [
                  Center(child: dayContent),
                  Positioned(
                    top: 2,
                    right: 3,
                    child: Text(moonSymbol!,
                        style: const TextStyle(fontSize: 9)),
                  ),
                ],
              )
            : Center(child: dayContent),
      ),
    );
  }
}

bool _isItemPast(_UpcomingItem item, DateTime now) {
  if (item.festival != null) {
    final d = item.festival!.gregorianDate.toLocal();
    final endOfDay = DateTime(d.year, d.month, d.day).add(const Duration(days: 1));
    return !now.isBefore(endOfDay);
  }
  final e = item.event!;
  if (e.startMinutes == null) {
    final d = e.gregorianDate;
    final endOfDay = DateTime(d.year, d.month, d.day).add(const Duration(days: 1));
    return !now.isBefore(endOfDay);
  }
  final endMin = e.startMinutes! + (e.durationMinutes ?? 60);
  final endTime = DateTime(
    e.gregorianDate.year, e.gregorianDate.month, e.gregorianDate.day,
    endMin ~/ 60, endMin % 60,
  );
  return now.isAfter(endTime);
}

DateTime _itemSortKey(_UpcomingItem item) {
  if (item.festival != null) {
    return item.festival!.gregorianDate.toLocal();
  }
  final e = item.event!;
  if (e.startMinutes == null) {
    return DateTime(e.gregorianDate.year, e.gregorianDate.month, e.gregorianDate.day);
  }
  return DateTime(
    e.gregorianDate.year, e.gregorianDate.month, e.gregorianDate.day,
    e.startMinutes! ~/ 60, e.startMinutes! % 60,
  );
}

Color _parseHex(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppColors.dark.gold;
  }
}
