/// Shared constants, helpers, and widgets used by both [DayView] and [WeekView].
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─── Layout constants ─────────────────────────────────────────────────────────

const double kTimeSlotH  = 52.0;
const int    kHourStart  = 0;
const int    kHourEnd    = 24;
const double kTimeGutterW = 44.0;

// ─── Color helper ─────────────────────────────────────────────────────────────

/// Parses a CSS hex color string (e.g. `#c9a84c`) into a [Color].
/// Falls back to the app's gold color on parse failure.
Color parseHexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppColors.dark.gold;
  }
}

// ─── Now-line widget ──────────────────────────────────────────────────────────

/// Red dot + horizontal rule indicating the current time in a time grid.
class TimeGridNowLine extends StatelessWidget {
  const TimeGridNowLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFcc2020),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(child: Container(height: 2, color: const Color(0xFFcc2020))),
      ],
    );
  }
}
