import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'db/database.dart';
import 'db/events_dao.dart';
import 'engine/celtic_calendar.dart';
import 'screens/calendar_screen.dart';
import 'services/google_calendar_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(RootsCalendarApp(db: db));
}

class RootsCalendarApp extends StatefulWidget {
  final AppDatabase db;

  const RootsCalendarApp({super.key, required this.db});

  @override
  State<RootsCalendarApp> createState() => _RootsCalendarAppState();
}

class _RootsCalendarAppState extends State<RootsCalendarApp>
    with WidgetsBindingObserver {

  late final GoogleCalendarService _gcal;

  @override
  void initState() {
    super.initState();
    _gcal = GoogleCalendarService(widget.db.eventsDao);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _gcal.backgroundSync(celticYearOf(DateTime.now())));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gcal.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _gcal.backgroundSync(celticYearOf(DateTime.now()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>(create: (_) => widget.db),
        Provider<EventsDao>(create: (_) => widget.db.eventsDao),
        ChangeNotifierProvider<GoogleCalendarService>.value(value: _gcal),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
        // AppColors is derived from ThemeNotifier — rebuilds when theme changes.
        ProxyProvider<ThemeNotifier, AppColors>(
          update: (_, notifier, __) =>
              notifier.isLight ? AppColors.light : AppColors.dark,
        ),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, notifier, _) => MaterialApp(
          title: 'Roots Calendar',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: notifier.isLight ? ThemeMode.light : ThemeMode.dark,
          home: const CalendarScreen(),
        ),
      ),
    );
  }
}
