// library lumin_flutter;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime startOfToday() {
  DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime startOfThisWeek() {
  DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day - now.weekday);
}

DateTime startOfThisMonth() {
  DateTime now = DateTime.now();
  return DateTime(now.year, now.month, 1);
}

DateTime startOfThisYear() {
  DateTime now = DateTime.now();
  return DateTime(now.year, 1, 1);
}

class LuminInfo {
  final String platform;
  final String platformVersion;
  final String appVersion;
  final String luminVersion;
  final String buildNumber;

  LuminInfo({
    required this.platform,
    required this.platformVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.luminVersion,
  });
}

class TrackingIntervals {
  final int? dau;
  final int? wau;
  final int? mau;
  final int? yau;

  TrackingIntervals({
    this.dau,
    this.wau,
    this.mau,
    this.yau,
  });
}

enum LuminProtocol {
  http,
  https,
}

class LuminConfig {
  final String url;
  final String environment;
  final bool automaticallyTrackActiveUsers;
  final bool logResponse;
  final bool logError;
  final TrackingIntervals? trackingIntervals;
  final LuminProtocol protocol;

  LuminConfig({
    // this.url = 'app.uselumin.co',
    this.url = 'localhost:3000',
    this.environment = 'default',
    this.automaticallyTrackActiveUsers = true,
    this.trackingIntervals,
    this.logResponse = false,
    this.logError = true,
    this.protocol = LuminProtocol.https,
  });
}

class AsyncStorageKeys {
  final String firstOpenTime;
  final String endOfLastSession;
  final String lastDauTracked;
  final String lastWauTracked;
  final String lastMauTracked;
  final String lastYauTracked;

  AsyncStorageKeys({
    required this.firstOpenTime,
    required this.endOfLastSession,
    required this.lastDauTracked,
    required this.lastWauTracked,
    required this.lastMauTracked,
    required this.lastYauTracked,
  });
}

class LuminApp {
  String appId;
  String appToken;

  final LuminConfig configuration;

  late final LuminInfo info;

  late final AsyncStorageKeys asyncStorageKeys;

  DateTime sessionStartTime;

  LuminApp(String token, [LuminConfig? configuration])
      : configuration = configuration ?? LuminConfig(),
        appId = '',
        appToken = '',
        sessionStartTime = DateTime.now() {
    final List<String> appIdAndAppToken = token.trim().split(':');
    final String appId = appIdAndAppToken[0];
    final String appToken = appIdAndAppToken[1];

    if (appId.isEmpty || appToken.isEmpty) {
      throw Exception('Lumin token malformed!');
    }

    this.appId = appId;
    this.appToken = appToken;

    asyncStorageKeys = AsyncStorageKeys(
      firstOpenTime: 'lumin_${appId}_first_open_time',
      endOfLastSession: 'lumin_${appId}_end_of_last_session',
      lastDauTracked: 'lumin_${appId}_last_dau_tracked',
      lastWauTracked: 'lumin_${appId}_last_wau_tracked',
      lastMauTracked: 'lumin_${appId}_last_mau_tracked',
      lastYauTracked: 'lumin_${appId}_last_yau_tracked',
    );
  }

  Future<void> init() async {
    info = LuminInfo(
      platform: Platform.operatingSystem,
      platformVersion: Platform.operatingSystemVersion,
      appVersion: (await PackageInfo.fromPlatform()).version,
      buildNumber: (await PackageInfo.fromPlatform()).buildNumber,
      luminVersion: '0.0.1',
    );

    setFirstOpenTime();

    if (configuration.automaticallyTrackActiveUsers) {
      trackActiveUser();
    }

    startSession();
  }

  Future<void> track(String event,
      [Map<String, dynamic> data = const {}]) async {
    try {
      var url = configuration.protocol == LuminProtocol.https
          ? Uri.https(configuration.url, '/api/events/create')
          : Uri.http(configuration.url, '/api/events/create');

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      final Map<String, dynamic> body = {
        'type': event,
        'data': {...data},
        'environment': 'default',
        'appToken': appToken,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );
    } catch (err) {
      print(err);
      rethrow;
    }
  }

  Future<void> trackCustomEvent(String event,
      [Map<String, dynamic> data = const {}]) async {
    await track(event, {r'$custom': true, ...data});
  }

  Future<void> startSession() async {
    sessionStartTime = DateTime.now();

    final sharedPreferences = await SharedPreferences.getInstance();

    final lastSessionEndTime = sharedPreferences.getString(
      asyncStorageKeys.endOfLastSession,
    );

    int? diff;

    if (lastSessionEndTime != null) {
      diff = DateTime.now()
          .difference(DateTime.parse(lastSessionEndTime))
          .inSeconds;
    }

    await track('SESSION_START', {
      'timeSinceLastSession': diff,
    });
  }

  Future<void> endSession() async {
    final diff = DateTime.now().difference(sessionStartTime).inSeconds;

    await track('SESSION_END', {
      'duration': diff,
    });

    final sharedPreferences = await SharedPreferences.getInstance();

    await sharedPreferences.setString(
      asyncStorageKeys.endOfLastSession,
      DateTime.now().toString(),
    );
  }

  Future<void> setFirstOpenTime() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    final firstOpenTime = sharedPreferences.getString(
      asyncStorageKeys.firstOpenTime,
    );

    if (firstOpenTime == null) {
      await sharedPreferences.setString(
        asyncStorageKeys.firstOpenTime,
        DateTime.now().toString(),
      );

      await track('FIRST_OPEN');
    }
  }

  Future<DateTime?> getFirstOpenTime() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    final firstOpenTime = sharedPreferences.getString(
      asyncStorageKeys.firstOpenTime,
    );

    if (firstOpenTime != null) {
      return DateTime.parse(firstOpenTime);
    }

    return null;
  }

  Future<void> trackActiveUser() async {
    trackDailyActiveUser();
    trackWeeklyActiveUser();
    trackMonthlyActiveUser();
    trackYearlyActiveUser();
  }

  Future<void> trackDailyActiveUser() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    final lastTimeActive = sharedPreferences.getString(
      asyncStorageKeys.lastDauTracked,
    );

    if (lastTimeActive != null) {
      final timeCondition = configuration.trackingIntervals?.dau != null
          ? DateTime.now()
                  .difference(DateTime.parse(lastTimeActive))
                  .inSeconds >
              configuration.trackingIntervals!.dau!
          : DateTime.parse(lastTimeActive).isBefore(startOfToday());

      if (timeCondition) {
        try {
          await track('DAILY_ACTIVE_USER');
          await sharedPreferences.setString(
            asyncStorageKeys.lastDauTracked,
            DateTime.now().toString(),
          );
        } catch (err) {
          if (configuration.logError) print(err);

          rethrow;
        }
      }
    } else {
      try {
        await track('DAILY_ACTIVE_USER');
        await sharedPreferences.setString(
          asyncStorageKeys.lastDauTracked,
          DateTime.now().toString(),
        );
      } catch (err) {
        if (configuration.logError) print(err);

        rethrow;
      }
    }
  }

  Future<void> trackWeeklyActiveUser() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    final lastTimeActive = sharedPreferences.getString(
      asyncStorageKeys.lastWauTracked,
    );

    if (lastTimeActive != null) {
      final timeCondition = configuration.trackingIntervals?.wau != null
          ? DateTime.now()
                  .difference(DateTime.parse(lastTimeActive))
                  .inSeconds >
              configuration.trackingIntervals!.wau!
          : DateTime.parse(lastTimeActive).isBefore(startOfThisWeek());

      if (timeCondition) {
        try {
          await track('WEEKLY_ACTIVE_USER');
          await sharedPreferences.setString(
            asyncStorageKeys.lastWauTracked,
            DateTime.now().toString(),
          );
        } catch (err) {
          if (configuration.logError) print(err);

          rethrow;
        }
      }
    } else {
      try {
        await track('WEEKLY_ACTIVE_USER');
        await sharedPreferences.setString(
          asyncStorageKeys.lastWauTracked,
          DateTime.now().toString(),
        );
      } catch (err) {
        if (configuration.logError) print(err);

        rethrow;
      }
    }
  }

  Future<void> trackMonthlyActiveUser() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    final lastTimeActive = sharedPreferences.getString(
      asyncStorageKeys.lastMauTracked,
    );

    if (lastTimeActive != null) {
      final timeCondition = configuration.trackingIntervals?.mau != null
          ? DateTime.now()
                  .difference(DateTime.parse(lastTimeActive))
                  .inSeconds >
              configuration.trackingIntervals!.mau!
          : DateTime.parse(lastTimeActive).isBefore(startOfThisMonth());

      if (timeCondition) {
        try {
          await track('MONTHLY_ACTIVE_USER');
          await sharedPreferences.setString(
            asyncStorageKeys.lastMauTracked,
            DateTime.now().toString(),
          );
        } catch (err) {
          if (configuration.logError) print(err);

          rethrow;
        }
      }
    } else {
      try {
        await track('MONTHLY_ACTIVE_USER');
        await sharedPreferences.setString(
          asyncStorageKeys.lastMauTracked,
          DateTime.now().toString(),
        );
      } catch (err) {
        if (configuration.logError) print(err);

        rethrow;
      }
    }
  }

  Future<void> trackYearlyActiveUser() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    final lastTimeActive = sharedPreferences.getString(
      asyncStorageKeys.lastYauTracked,
    );

    if (lastTimeActive != null) {
      final timeCondition = configuration.trackingIntervals?.yau != null
          ? DateTime.now()
                  .difference(DateTime.parse(lastTimeActive))
                  .inSeconds >
              configuration.trackingIntervals!.yau!
          : DateTime.parse(lastTimeActive).isBefore(startOfThisYear());

      if (timeCondition) {
        try {
          await track('YEARLY_ACTIVE_USER');
          await sharedPreferences.setString(
            asyncStorageKeys.lastYauTracked,
            DateTime.now().toString(),
          );
        } catch (err) {
          if (configuration.logError) print(err);

          rethrow;
        }
      }
    } else {
      try {
        await track('YEARLY_ACTIVE_USER');
        await sharedPreferences.setString(
          asyncStorageKeys.lastYauTracked,
          DateTime.now().toString(),
        );
      } catch (err) {
        if (configuration.logError) print(err);

        rethrow;
      }
    }
  }

  void clearLuminFromSharedPreferences() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    await sharedPreferences.remove(asyncStorageKeys.lastDauTracked);
    await sharedPreferences.remove(asyncStorageKeys.lastWauTracked);
    await sharedPreferences.remove(asyncStorageKeys.lastMauTracked);
    await sharedPreferences.remove(asyncStorageKeys.lastYauTracked);
  }
}

class Lumin {
  static LuminApp? _instance;

  static Future<LuminApp> init(String token,
      [LuminConfig? configuration]) async {
    _instance = LuminApp(token, configuration);

    await _instance!.init();

    return _instance!;
  }

  static LuminApp get instance {
    if (_instance == null) {
      throw Exception('Lumin not initialized!');
    }

    return _instance!;
  }
}

class LuminLifecycleLogger extends StatefulWidget {
  final Widget child;

  const LuminLifecycleLogger({Key? key, required this.child}) : super(key: key);

  @override
  _LuminLifecycleLoggerState createState() => _LuminLifecycleLoggerState();
}

class _LuminLifecycleLoggerState extends State<LuminLifecycleLogger>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      if (Lumin.instance.configuration.automaticallyTrackActiveUsers) {
        Lumin.instance.trackActiveUser();
      }

      Lumin.instance.startSession();
    } else if (state == AppLifecycleState.paused) {
      Lumin.instance.endSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
