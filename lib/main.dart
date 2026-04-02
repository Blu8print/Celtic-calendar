import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'db/database.dart';
import 'db/events_dao.dart';
import 'engine/celtic_calendar.dart';
import 'screens/calendar_screen.dart';
import 'services/google_calendar_service.dart';
import 'theme/app_theme.dart';

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
    // Initial sync fires once after the first frame.
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
      _gcal.backgroundSync(celticYearOf(DateTime.now())); // fire-and-forget
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Database and DAO
        Provider<AppDatabase>(create: (_) => widget.db),
        Provider<EventsDao>(create: (_) => widget.db.eventsDao),

        // Google Calendar service — ChangeNotifier so UI reacts to sign-in state.
        ChangeNotifierProvider<GoogleCalendarService>.value(value: _gcal),
      ],
      child: MaterialApp(
        title: 'Roots Calendar',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const CalendarScreen(),
      ),
    );
  }
}
