import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';

/// Full-width card shown in the grid area when the current view is Year Day.
class YearDayCard extends StatelessWidget {
  final int celticYear;
  final VoidCallback? onTap;

  const YearDayCard({
    super.key,
    required this.celticYear,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final yd = yearDayDate(celticYear);
    final today = DateTime.now();
    final isToday = yd.year == today.year &&
        yd.month == today.month &&
        yd.day == today.day;
    final fmt = DateFormat('d MMM yyyy');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.yearDayBg,
            border: Border.all(
              color: isToday ? AppColors.ydGoldBorder : AppColors.ydBorder,
              width: isToday ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              Text(
                '☽  YEAR AND A DAY  ☾',
                style: AppTextStyles.cinzel(
                  size: 15,
                  color: AppColors.ydTitle,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                fmt.format(yd),
                style: AppTextStyles.imFell(size: 12, color: AppColors.ydGreg),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This day stands outside the calendar —\n'
                'a threshold between years, belonging to no month.\n'
                'A time for rest, reflection, and passage.',
                style: AppTextStyles.imFell(
                  size: 13,
                  color: AppColors.ydDesc,
                  italic: true,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
