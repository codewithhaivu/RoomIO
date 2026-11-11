import 'dart:async';

import 'package:flutter/material.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/usecases/get_conversations_usecase.dart';
import 'package:roomio/features/notification/application/notification_device_sync.dart';

class PushNotificationNavigator extends NavigatorObserver {
  PushNotificationNavigator(this._devices, this._getConversations);

  final NotificationDeviceSync _devices;
  final GetConversationsUseCase _getConversations;
  Route<dynamic>? _topRoute;
  Object? _readySession;
  bool _startupResolved = false;
  ({String type, String id, Object? session})? _pending;
  int _tapSequence = 0;

  void resolveStartup() {
    if (_startupResolved) return;
    _startupResolved = true;
    _readySession = _devices.session;
    if (_readySession == null) _pending = null;
    _scheduleOpen();
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _topRoute = topRoute;
    // A fresh login uses the existing profile flow before pushing Home.
    if (topRoute.settings.name == AppRoutes.home) {
      _readySession = _devices.session;
    }
    _scheduleOpen();
  }

  bool shouldShow(Map<String, dynamic> data) {
    if (_devices.session == null) return false;
    final target = _target(data);
    return target == null ||
        target.type != 'chat' ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !_isViewingChat(target.id);
  }

  void onTap(Map<String, dynamic> data) {
    final session = _devices.session;
    if (_startupResolved && session == null) return;
    final target = _target(data);
    if (target == null) return;
    _pending = (type: target.type, id: target.id, session: session);
    _tapSequence++;
    _scheduleOpen();
  }

  void _scheduleOpen() {
    if (!_startupResolved || _pending == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _pending;
      final nav = navigator;
      if (target == null || nav == null) return;
      if (target.session != null && target.session != _devices.session) {
        _pending = null;
        return;
      }
      final session = _readySession;
      if (!_canOpen(session)) return;
      _pending = null;
      if (target.type == 'appointment') {
        nav.pushNamed<void>(
          AppRoutes.appointments,
          arguments: {'appointmentId': target.id},
        );
      } else if (!_isViewingChat(target.id)) {
        unawaited(_openChat(nav, target.id, session!, _tapSequence));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openChat(
    NavigatorState nav,
    String senderId,
    Object session,
    int sequence,
  ) async {
    ConversationResponse? conversation;
    try {
      final result = await _getConversations(null);
      conversation = result.data
          ?.where((item) => item.targetUserId == senderId)
          .firstOrNull;
    } catch (_) {
      debugPrint('RoomIO: Không tìm được hội thoại từ thông báo.');
    }
    if (!nav.mounted || !_canOpen(session) || sequence != _tapSequence) return;
    if (_isViewingChat(senderId)) return;
    if (conversation == null) {
      nav.pushNamed<void>(AppRoutes.chatList);
    } else {
      nav.pushNamed<void>(AppRoutes.chat, arguments: conversation);
    }
  }

  bool _canOpen(Object? session) =>
      session != null && session == _devices.session;

  bool _isViewingChat(String senderId) {
    final settings = _topRoute?.settings;
    final conversation = settings?.arguments;
    return settings?.name == AppRoutes.chat &&
        conversation is ConversationResponse &&
        conversation.targetUserId == senderId;
  }

  ({String type, String id})? _target(Map<String, dynamic> data) {
    final type = data['type'];
    final id = switch (type) {
      'chat' => data['sender_id'],
      'appointment' => data['appointment_id'],
      _ => null,
    };
    if (id is! String || id.trim().isEmpty) return null;
    return (type: type as String, id: id);
  }
}
