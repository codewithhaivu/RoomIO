import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // RoomIO sends a notification payload. Android displays it in the background.
}

class FcmService {
  static const _icon = 'ic_notification';
  static const _channel = AndroidNotificationChannel(
    'roomio_push',
    'Thông báo RoomIO',
    description: 'Tin nhắn và lịch hẹn xem phòng',
    importance: Importance.high,
  );
  static const _tokenTimeout = Duration(seconds: 5);

  final _local = FlutterLocalNotificationsPlugin();
  final _shown = <String>{};
  final _opened = <String>{};
  FirebaseMessaging? _messaging;
  Future<void>? _initialization;
  Future<void>? _permissionRequest;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _localReady = false;
  int _nextLocalId = 0;

  Future<void> initialize({
    required bool Function(Map<String, dynamic>) shouldShow,
    required void Function(Map<String, dynamic>) onTap,
  }) => _initialization ??= _initialize(shouldShow, onTap);

  Future<void> _initialize(
    bool Function(Map<String, dynamic>) shouldShow,
    void Function(Map<String, dynamic>) onTap,
  ) async {
    if (!isSupported) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      _messaging = FirebaseMessaging.instance;
    } catch (_) {
      debugPrint('RoomIO: Không khởi tạo được Firebase Messaging.');
      return;
    }

    void openRemote(RemoteMessage message) {
      if (_remember(_opened, message.messageId)) onTap(message.data);
    }

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      openRemote,
    );
    unawaited(_openInitialRemoteMessage(openRemote));

    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _openLocal(response.payload, onTap),
      );
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_channel);
      _localReady = true;
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        if (shouldShow(message.data)) unawaited(_show(message));
      });

      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _openLocal(launch?.notificationResponse?.payload, onTap);
      }
    } catch (_) {
      debugPrint('RoomIO: Không khởi tạo được thông báo cục bộ.');
    }
  }

  Future<void> _openInitialRemoteMessage(
    void Function(RemoteMessage) onMessage,
  ) async {
    try {
      final initial = await _messaging?.getInitialMessage();
      if (initial != null) onMessage(initial);
    } catch (_) {
      debugPrint('RoomIO: Không đọc được thông báo đã mở ứng dụng.');
    }
  }

  void _openLocal(String? payload, void Function(Map<String, dynamic>) onTap) {
    if (payload == null) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final data = decoded['data'];
      final id = decoded['messageId'];
      if (data is Map<String, dynamic> &&
          _remember(_opened, id is String ? id : null)) {
        onTap(data);
      }
    } on FormatException {
      debugPrint('RoomIO: Dữ liệu thông báo cục bộ không hợp lệ.');
    }
  }

  Future<void> _show(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || !_remember(_shown, message.messageId)) return;

    try {
      await _local.show(
        id: message.messageId?.hashCode ?? ++_nextLocalId,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: _channel.importance,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode({
          'messageId': message.messageId,
          'data': message.data,
        }),
      );
    } catch (_) {
      debugPrint('RoomIO: Không hiển thị được thông báo cục bộ.');
    }
  }

  bool _remember(Set<String> ids, String? id) {
    if (id == null) return true;
    if (!ids.add(id)) return false;
    if (ids.length > 128) ids.remove(ids.first);
    return true;
  }

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get isAvailable => _messaging != null;

  // The RoomIO API accepts registration tokens. The new SDK API returns FIDs.
  Stream<String> get tokenRefresh =>
      // ignore: deprecated_member_use
      _messaging?.onTokenRefresh ?? const Stream.empty();

  Future<void> requestPermission() =>
      _permissionRequest ??= _requestPermission();

  Future<void> _requestPermission() async {
    try {
      await _messaging?.requestPermission();
    } catch (_) {
      debugPrint('RoomIO: Không yêu cầu được quyền thông báo.');
    }
  }

  Future<String?> getToken() async =>
      // ignore: deprecated_member_use
      _messaging?.getToken().timeout(_tokenTimeout);

  Future<void> deleteToken() async {
    // ignore: deprecated_member_use
    await _messaging?.deleteToken().timeout(_tokenTimeout);
  }

  Future<void> clearNotifications() async {
    if (_localReady) await _local.cancelAll().timeout(_tokenTimeout);
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
