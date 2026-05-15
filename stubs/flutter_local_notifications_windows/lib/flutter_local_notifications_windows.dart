import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';

/// ATL-free Windows implementation stub for flutter_local_notifications
class FlutterLocalNotificationsWindows
    extends FlutterLocalNotificationsPlatform {
  static void registerWith() {
    FlutterLocalNotificationsPlatform.instance =
        FlutterLocalNotificationsWindows();
  }

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return null;
  }

  // The main plugin expects this signature for Windows
  Future<bool?> initialize(
    WindowsInitializationSettings initializationSettings, {
    dynamic onNotificationReceived,
  }) async {
    return true;
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return [];
  }

  // The main plugin expects 'details' parameter name for Windows
  @override
  Future<void> show(
    int id,
    String? title,
    String? body, {
    WindowsNotificationDetails? details,
    String? payload,
  }) async {}

  // The main plugin calls this without uiLocalNotificationDateInterpretation for Windows
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    DateTime scheduledDate,
    WindowsNotificationDetails? notificationDetails, {
    String? payload,
    dynamic matchDateTimeComponents,
    String? uiLocalNotificationDateInterpretation,
  }) async {}

  @override
  Future<void> periodicallyShow(int id, String? title, String? body,
      RepeatInterval repeatInterval) async {}

  @override
  Future<void> showDailyAtTime(
      int id, String? title, String? body, dynamic notificationTime) async {}

  @override
  Future<void> showWeeklyAtDayAndTime(int id, String? title, String? body,
      dynamic day, dynamic notificationTime) async {}
}

class WindowsInitializationSettings {
  const WindowsInitializationSettings({
    required this.appName,
    this.appId,
    this.customIcon,
  });
  final String appName;
  final String? appId;
  final String? customIcon;
}

class WindowsNotificationDetails {
  const WindowsNotificationDetails({
    this.template,
    this.customXml,
  });
  final String? template;
  final String? customXml;
}
