import 'package:flutter/material.dart';

import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';

/// Horizontal scrollable strip of all 13 months + Year Day chip.
///
/// Active month chip is highlighted and scrolled into view.
class MonthStrip extends StatefulWidget {
  /// Currently active month (1-13), or null for Year Day.
  final int? activeMonth;
  final int celticYear;

  final void Function(int? month) onMonthSelected;

  const MonthStrip({
    super.key,
    required this.activeMonth,
    required this.celticYear,
    required this.onMonthSelected,
  });

  @override
  State<MonthStrip> createState() => _MonthStripState();
}

class _MonthStripState extends State<MonthStrip> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(MonthStrip old) {
    super.didUpdateWidget(old);
    if (old.activeMonth != widget.activeMonth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    // Each chip is approximately 50px wide with 4px gap.
    const chipWidth = 50.0 + 4.0;
    final index = widget.activeMonth == null ? 13 : (widget.activeMonth! - 1);
    final offset = index * chipWidth;
    if (_scroll.hasClients) {
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayCelticYear = celticYearOf(today);
    final todayInfo = gregorianToCeltic(today);

    return SizedBox(
      height: 54,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: 14, // 13 months + Year Day
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          if (index < 13) {
            final mo = celticMonths[index];
            final isActive = widget.activeMonth == mo.number;
            final hasToday = todayCelticYear == widget.celticYear &&
                !todayInfo.isYearDay &&
                !todayInfo.isLeapDay &&
                todayInfo.month == mo.number;
            return _StripChip(
              number: '${mo.number}',
              name: mo.name,
              isActive: isActive,
              hasToday: hasToday,
              onTap: () => widget.onMonthSelected(mo.number),
            );
          } else {
            // Year Day chip
            final isActive = widget.activeMonth == null;
            final hasToday = todayCelticYear == widget.celticYear &&
                (todayInfo.isYearDay || todayInfo.isLeapDay);
            return _StripChip(
              number: '☽',
              name: 'YrDay',
              isActive: isActive,
              hasToday: hasToday,
              onTap: () => widget.onMonthSelected(null),
            );
          }
        },
      ),
    );
  }
}

class _StripChip extends StatelessWidget {
  final String number;
  final String name;
  final bool isActive;
  final bool hasToday;
  final VoidCallback onTap;

  const _StripChip({
    required this.number,
    required this.name,
    required this.isActive,
    required this.hasToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    if (isActive) {
      borderColor = AppColors.gold;
    } else if (hasToday) {
      borderColor = AppColors.muted;
    } else {
      borderColor = AppColors.border;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 50,
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface2 : AppColors.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: AppTextStyles.cinzel(
                size: 9,
                color: AppColors.dim,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: AppTextStyles.cinzel(
                size: 11,
                color: isActive ? AppColors.gold : AppColors.text,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
