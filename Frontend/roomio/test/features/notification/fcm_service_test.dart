import 'package:firebase_messaging/firebase_messaging.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/firebase/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FCM foreground and tap events use one listener each', (
    tester,
  ) async {
    setupFirebaseCoreMocks();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
    const local = MethodChannel('dexterous.com/flutter/local_notifications');
    const coldStart = RemoteMessage(
      messageId: 'cold-start',
      data: {'type': 'appointment', 'appointment_id': 'appointment-1'},
    );
    const foreground = RemoteMessage(
      messageId: 'foreground',
      data: {'type': 'chat', 'sender_id': 'sender-1'},
      notification: RemoteNotification(title: 'Tin nhắn mới', body: 'RoomIO'),
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final firebaseCalls = <String>[];
    final localCalls = <MethodCall>[];
    final taps = <Map<String, dynamic>>[];
    messenger.setMockMethodCallHandler(messaging, (call) async {
      firebaseCalls.add(call.method);
      if (call.method == 'Messaging#getInitialMessage') {
        return coldStart.toMap();
      }
      return null;
    });
    messenger.setMockMethodCallHandler(local, (call) async {
      localCalls.add(call);
      if (call.method == 'initialize') return true;
      return null;
    });

    Future<void> deliver(
      MethodChannel channel,
      String event,
      Object arguments,
    ) async {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(event, arguments)),
        null,
      );
      await tester.pump();
    }

    final service = FcmService();
    addTearDown(service.dispose);
    bool show = true;
    Future<void> initialize() =>
        service.initialize(shouldShow: (_) => show, onTap: taps.add);
    await initialize();
    await initialize();
    await tester.pump();
    expect(
      firebaseCalls.where((call) => call == 'Messaging#getInitialMessage'),
      hasLength(1),
    );
    expect(firebaseCalls, contains('Messaging#startBackgroundIsolate'));
    expect(
      localCalls.where((call) => call.method == 'createNotificationChannel'),
      hasLength(1),
    );
    expect(taps, [coldStart.data]);

    await deliver(messaging, 'Messaging#onMessage', foreground.toMap());
    await deliver(messaging, 'Messaging#onMessage', foreground.toMap());
    show = false;
    await deliver(
      messaging,
      'Messaging#onMessage',
      foreground.toMap()..['messageId'] = 'suppressed',
    );
    final shown = localCalls.where((call) => call.method == 'show').single;
    expect(shown.arguments['title'], 'Tin nhắn mới');

    await deliver(local, 'didReceiveNotificationResponse', {
      'notificationId': shown.arguments['id'],
      'notificationResponseType': 0,
      'payload': shown.arguments['payload'],
    });
    await deliver(
      messaging,
      'Messaging#onMessageOpenedApp',
      foreground.toMap(),
    );
    expect(taps, [coldStart.data, foreground.data]);
  });
}
