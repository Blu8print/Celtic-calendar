import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'db/database.dart';
import 'db/events_dao.dart';
import 'engine/celtic_calendar.dart';
import 'screens/calendar_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/google_calendar_service.dart';
import 'services/home_widget_service.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';
import 'theme/moon_settings_notifier.dart';
import 'theme/sky_settings_notifier.dart';
import 'theme/theme_notifier.dart';

/// Global navigator key — used to route notification taps from outside the widget tree.
final _navigatorKey = GlobalKey<NavigatorState>();

void _openDateFromPayload(String payload) {
  try {
    final date = DateTime.parse(payload);
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => EventDetailScreen(date: date),
    ));
  } catch (e, stack) {
    debugPrint('Failed to open date from notification payload "$payload": $e\n$stack');
  }
}

/// Runs in a background isolate — must be a top-level function.
@pragma('vm:entry-point')
void _widgetUpdateDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final db = AppDatabase();
    try {
      await HomeWidgetService.updateTodayWidget(db.eventsDao);
    } catch (e, stack) {
      debugPrint('Widget update failed: $e\n$stack');
    } finally {
      await db.close();
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase (requires google-services.json on Android and
  // GoogleService-Info.plist on iOS — see GOOGLE_SETUP.md).
  // The app remains functional without it; crash reports just won't be sent.
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase not configured — crash reporting disabled: $e');
  }

  // Catch Flutter framework errors (widget build failures, rendering errors).
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    if (firebaseReady) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  // Catch async errors that escape all Zone boundaries (e.g. in Future callbacks).
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled platform error: $error\n$stack');
    if (firebaseReady) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await ReminderService.init();
  await ReminderService.requestPermissions();
  ReminderService.onNotificationTap = _openDateFromPayload;

  // Register periodic background widget refresh (runs even when app is closed).
  await Workmanager().initialize(_widgetUpdateDispatcher);
  await Workmanager().registerPeriodicTask(
    'roots_widget_refresh',
    'widgetRefresh',
    frequency: const Duration(minutes: 30),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );

  final db = AppDatabase();
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);
  runApp(RootsCalendarApp(db: db, showOnboarding: showOnboarding));
}

class RootsCalendarApp extends StatefulWidget {
  final AppDatabase db;
  final bool showOnboarding;

  const RootsCalendarApp({super.key, required this.db, this.showOnboarding = false});

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _gcal.backgroundSync(celticYearOf(DateTime.now()));
      HomeWidgetService.updateTodayWidget(widget.db.eventsDao);
      // Handle cold-start from notification tap.
      final payload = await ReminderService.getLaunchPayload();
      if (payload != null) _openDateFromPayload(payload);
    });
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
      HomeWidgetService.updateTodayWidget(widget.db.eventsDao);
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
        ChangeNotifierProvider<MoonSettingsNotifier>(create: (_) => MoonSettingsNotifier()),
        ChangeNotifierProvider<SkySettingsNotifier>(create: (_) => SkySettingsNotifier()),
        // AppColors is derived from ThemeNotifier — rebuilds when theme changes.
        ProxyProvider<ThemeNotifier, AppColors>(
          update: (_, notifier, __) =>
              notifier.isLight ? AppColors.light : AppColors.dark,
        ),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, notifier, _) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                notifier.isLight ? Brightness.dark : Brightness.light,
          ));
          return MaterialApp(
            title: 'Roots Calendar',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: notifier.isLight ? ThemeMode.light : ThemeMode.dark,
            home: widget.showOnboarding
                ? const OnboardingScreen()
                : const CalendarScreen(),
          );
        },
      ),
    );
  }
}
