import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/celtic_calendar.dart';
import '../services/google_calendar_service.dart';
import '../theme/app_theme.dart';
import 'calendar_screen.dart';

// Shorthand constants — always the light palette.
const _c = AppColors.light;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  void _next() => _ctrl.nextPage(
      duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.bg,
      body: Stack(
        children: [
          PageView(
            controller: _ctrl,
            onPageChanged: (p) => setState(() => _page = p),
            children: const [_Page1(), _Page2(), _Page3()],
          ),
          Positioned(
            bottom: 32,
            left: 28,
            right: 28,
            child: _NavOverlay(page: _page, onNext: _next, onFinish: _finish),
          ),
        ],
      ),
    );
  }
}

// ── Page 1 — The Calendar ─────────────────────────────────────────────────────

class _Page1 extends StatelessWidget {
  const _Page1();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            // Ogham letter
            Text(
              'ᚁ',
              style: AppTextStyles.cinzel(size: 48, color: _c.gold)
                  .copyWith(color: _c.gold.withValues(alpha: 0.4)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Heading
            Text(
              'Thirteen months.\nTwenty-eight days each.',
              style: AppTextStyles.cinzel(
                  size: 26, weight: FontWeight.w700, color: _c.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Subheading
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                'A year of 364 days — plus one day that belongs to no month.',
                style: AppTextStyles.imFell(size: 15, color: _c.dim, italic: true),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            // Mini calendar
            const _MiniCalendar(),
            const SizedBox(height: 20),
            // Caption
            Text(
              'Every month is exactly four weeks.\nEvery week always starts on the same day.',
              style: AppTextStyles.imFell(size: 13, color: _c.dim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar();

  static const _todayCell = 19; // arbitrary highlighted cell

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (week) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Week label
              SizedBox(
                width: 32,
                child: Text(
                  'Wk ${week + 1}',
                  style: AppTextStyles.cinzel(size: 9, color: _c.dim),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 6),
              // 7 day cells
              ...List.generate(7, (day) {
                final cellNum = week * 7 + day + 1;
                final isToday = cellNum == _todayCell;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isToday ? _c.muted : _c.surface,
                      border: Border.all(color: _c.border, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$cellNum',
                      style: AppTextStyles.cinzel(
                          size: 11,
                          color: isToday ? Colors.white : _c.text),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }
}

// ── Page 2 — The Tree Month ───────────────────────────────────────────────────

class _Page2 extends StatelessWidget {
  const _Page2();

  static final _dateFmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final celticDate = gregorianToCeltic(today);
    final celticYear = celticYearOf(today);
    final mo = celticDate.isYearDay || celticDate.isLeapDay
        ? celticMonths[0] // fallback to Beth if on Year Day
        : celticMonths[(celticDate.month ?? 1) - 1];

    String dateRange = '';
    if (!celticDate.isYearDay && !celticDate.isLeapDay) {
      final dates = gregorianDatesForMonth(celticYear, mo.number);
      dateRange =
          '${_dateFmt.format(dates.first)} – ${_dateFmt.format(dates.last)}';
    }

    const teaserMonths = [
      ('Beth', 'New Beginnings'),
      ('Luis', 'Protection'),
      ('Nion', 'Connection'),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Ogham char
            Text(
              mo.ogham,
              style: AppTextStyles.cinzel(size: 40, color: _c.gold)
                  .copyWith(color: _c.gold.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Month name
            Text(
              mo.name,
              style: AppTextStyles.cinzel(
                  size: 32, weight: FontWeight.w700, color: _c.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Tree name
            Text(
              mo.tree.toUpperCase(),
              style: AppTextStyles.cinzel(
                  size: 12, color: _c.dim, letterSpacing: 2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Keyword pill
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _c.surface2,
                border: Border.all(color: _c.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                mo.keyword,
                style: AppTextStyles.imFell(
                    size: 12, color: _c.gold, italic: true),
              ),
            ),
            if (dateRange.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                dateRange,
                style: AppTextStyles.cinzel(size: 11, color: _c.dim),
              ),
            ],
            const SizedBox(height: 28),
            // Body
            Text(
              'Each month is named after a sacred tree.\nEach tree carries a teaching.',
              style: AppTextStyles.imFell(size: 15, color: _c.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Tree teaser
            ...teaserMonths.map((pair) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(pair.$1,
                          style: AppTextStyles.cinzel(
                              size: 12, color: _c.dim)),
                      Text('  ·  ',
                          style: AppTextStyles.cinzel(
                              size: 12, color: _c.border)),
                      Text(pair.$2,
                          style: AppTextStyles.imFell(
                              size: 12, color: _c.dim, italic: true)),
                    ],
                  ),
                )),
            Text(
              '· · ·',
              style: AppTextStyles.cinzel(size: 12, color: _c.border),
            ),
            const SizedBox(height: 24),
            // Closing
            Text(
              'Thirteen trees. Thirteen teachings. One year.',
              style:
                  AppTextStyles.imFell(size: 14, color: _c.gold, italic: true),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 120), // space for nav overlay
          ],
        ),
      ),
    );
  }
}

// ── Page 3 — Your Events ──────────────────────────────────────────────────────

class _Page3 extends StatelessWidget {
  const _Page3();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 56),
            // Heading
            Text(
              'Your life, in Celtic time.',
              style: AppTextStyles.cinzel(
                  size: 26, weight: FontWeight.w700, color: _c.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Body
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                'Roots Calendar lives alongside your existing calendars. '
                'Your events appear here, rooted in the rhythm of the trees.',
                style: AppTextStyles.imFell(size: 15, color: _c.dim),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            // Google connect card
            Consumer<GoogleCalendarService>(
              builder: (context, gcal, _) {
                if (gcal.isSignedIn) {
                  return _ConnectedCard();
                }
                return _ConnectCard(onTap: gcal.signIn);
              },
            ),
            const SizedBox(height: 16),
            // Skip link
            TextButton(
              onPressed: () {}, // Begin button handles exit
              child: Text(
                "I'll set this up later",
                style:
                    AppTextStyles.imFell(size: 13, color: _c.dim, italic: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ConnectCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _c.surface,
          border: Border.all(color: _c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, color: _c.muted, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect Google Calendar',
                    style: AppTextStyles.cinzel(size: 14, color: _c.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'See your existing events in the Celtic calendar. Optional.',
                    style: AppTextStyles.imFell(size: 12, color: _c.dim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface,
        border: Border.all(color: _c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: _c.muted, size: 28),
          const SizedBox(width: 14),
          Text(
            'Connected',
            style: AppTextStyles.cinzel(size: 14, color: _c.muted),
          ),
        ],
      ),
    );
  }
}

// ── Navigation overlay ────────────────────────────────────────────────────────

class _NavOverlay extends StatelessWidget {
  final int page;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _NavOverlay({
    required this.page,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DotIndicator(count: 3, current: page),
        const SizedBox(height: 16),
        Row(
          children: [
            if (page < 2)
              TextButton(
                onPressed: onFinish,
                child: Text(
                  'Skip',
                  style: AppTextStyles.imFell(
                      size: 13, color: _c.dim, italic: true),
                ),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: page < 2 ? onNext : onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: _c.muted,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                page < 2 ? 'Continue' : 'Begin',
                style: AppTextStyles.cinzel(size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == current ? 10 : 8,
            height: i == current ? 10 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? _c.muted : _c.border,
            ),
          ),
        ),
      ),
    );
  }
}
