import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A persistent (ongoing, non-swipeable) notification with quick actions
/// for an active Walk With Me journey, so the student can use other apps
/// while it's running rather than having to keep SafeStep in the
/// foreground (feedback: "make it like a floating widget/ball ... so I
/// can use other apps while in journey").
///
/// This works as long as the app process is still alive (foreground or
/// recently backgrounded) — action taps are handled in-process. It is
/// NOT a true system-wide overlay and won't survive the app being force-
/// killed; that would need a foreground service, which is a separate,
/// heavier task.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _channelId = 'walk_with_me';
  static const _journeyNotificationId = 1001;
  static const actionExtend = 'extend';
  static const actionArrived = 'arrived';

  static const _alertStatusChannelId = 'alert_status';
  int _alertStatusNotificationId = 2001;

  static const _monitoredJourneyChannelId = 'monitored_journeys';
  int _monitoredJourneyNotificationId = 3001;

  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(String actionId)? onAction;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId != null) onAction?.call(response.actionId!);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showJourneyNotification({
    required String title,
    required String body,
    bool showExtendAction = true,
  }) async {
    final details = AndroidNotificationDetails(
      _channelId,
      'Safe Walks',
      channelDescription: 'Ongoing journey status while Safe Walks is active',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      actions: [
        if (showExtendAction)
          const AndroidNotificationAction(
            actionExtend,
            'Extend 10 min',
            showsUserInterface: false,
          ),
        const AndroidNotificationAction(
          actionArrived,
          "I've Arrived",
          showsUserInterface: false,
        ),
      ],
    );
    await _plugin.show(
      _journeyNotificationId,
      title,
      body,
      NotificationDetails(android: details),
    );
  }

  Future<void> cancelJourneyNotification() async {
    await _plugin.cancel(_journeyNotificationId);
  }

  /// A one-shot notification for a responder's status update on a
  /// specific student's own alert (Acknowledged/Dispatched/Resolved).
  /// Each call uses a fresh notification id so multiple updates stack
  /// rather than overwrite one another, unlike the ongoing journey
  /// notification above.
  Future<void> showAlertStatusNotification({
    required String title,
    required String body,
  }) async {
    const details = AndroidNotificationDetails(
      _alertStatusChannelId,
      'Alert updates',
      channelDescription: "Updates from a responder on your own SafeStep alert",
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      _alertStatusNotificationId++,
      title,
      body,
      const NotificationDetails(android: details),
    );
  }

  /// A one-shot notification for someone who picked this student as a
  /// "Monitor My Journey" contact, fired as soon as the journey is seen
  /// to have started (see MonitoredJourneyPoller).
  Future<void> showMonitoredJourneyNotification({
    required String title,
    required String body,
  }) async {
    const details = AndroidNotificationDetails(
      _monitoredJourneyChannelId,
      'Journeys you monitor',
      channelDescription:
          "Someone who added you as a monitor has started a Safe Walks journey",
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      _monitoredJourneyNotificationId++,
      title,
      body,
      const NotificationDetails(android: details),
    );
  }
}
