import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:roomio/core/firebase/fcm_service.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/notification/domain/usecases/register_device.dart';
import 'package:roomio/features/notification/domain/usecases/unregister_device.dart';
import 'package:roomio/features/notification/domain/usecases/update_device.dart';

class NotificationDeviceSync {
  NotificationDeviceSync(
    this._fcm,
    this._storage,
    this._registerDevice,
    this._updateDevice,
    this._unregisterDevice,
  );

  final FcmService _fcm;
  final FlutterSecureStorage _storage;
  final RegisterDeviceUseCase _registerDevice;
  final UpdateDeviceUseCase _updateDevice;
  final UnregisterDeviceUseCase _unregisterDevice;

  final _deviceIds = <String, String>{};
  StreamSubscription<String>? _tokenSubscription;
  Future<void> _work = Future.value();
  ({String accountId, Object identity})? _session;
  String? _syncedToken;
  int _tokenRevision = 0;

  Object? get session => _session?.identity;

  void startSession(String accessToken) {
    final accountId = _readAccountId(accessToken);
    if (accountId == null || accountId == _session?.accountId) return;

    final identity = Object();
    _session = (accountId: accountId, identity: identity);
    _syncedToken = null;
    if (!_fcm.isAvailable) return;

    _tokenSubscription ??= _fcm.tokenRefresh.listen(
      _onTokenRefresh,
      onError: (Object _) =>
          debugPrint('RoomIO: Không nhận được token FCM mới.'),
    );
    unawaited(_fcm.requestPermission());

    final revision = _tokenRevision;
    unawaited(
      _enqueue(() async {
        if (session != identity || revision != _tokenRevision) return;
        final token = await _fcm.getToken();
        if (token != null && revision == _tokenRevision) {
          await _syncToken(accountId, identity, token);
        }
      }),
    );
  }

  void _onTokenRefresh(String token) {
    final current = _session;
    if (current == null) return;
    final revision = ++_tokenRevision;
    unawaited(
      _enqueue(() async {
        if (revision == _tokenRevision) {
          await _syncToken(current.accountId, current.identity, token);
        }
      }),
    );
  }

  Future<void> _syncToken(
    String accountId,
    Object identity,
    String token,
  ) async {
    if (session != identity || token.isEmpty || token == _syncedToken) return;
    final key = _deviceKey(accountId);
    final id = await _readDeviceId(key);
    if (session != identity) return;

    if (id != null) {
      final result = await _updateDevice((fcmToken: token, idDevice: id));
      if (result is DataSuccess) {
        if (session == identity) _syncedToken = token;
        return;
      }
      final response = result.error?.response;
      final body = response?.data;
      if (response?.statusCode != 404 ||
          body is! Map ||
          body['detail'] != 'not found devices') {
        debugPrint('RoomIO: Không cập nhật được thiết bị nhận thông báo.');
        return;
      }
    }

    if (session != identity) return;
    final registered = await _registerDevice((
      fcmToken: token,
      platform: 'android',
    ));
    final newId = registered.data;
    if (registered is! DataSuccess || newId == null || newId.isEmpty) {
      debugPrint('RoomIO: Không đăng ký được thiết bị nhận thông báo.');
      return;
    }

    // A logout queued during POST needs the returned ID to delete the record.
    _deviceIds[key] = newId;
    await _storage.write(key: key, value: newId);
    if (session == identity) _syncedToken = token;
  }

  Future<void> unregisterSession() {
    final current = _session;
    _session = null;
    if (current == null || !_fcm.isSupported) return Future.value();

    return _enqueue(() async {
      final key = _deviceKey(current.accountId);
      var unregistered = false;
      try {
        final id = await _readDeviceId(key);
        if (id != null) {
          final result = await _unregisterDevice(id);
          unregistered = result is DataSuccess;
          if (unregistered) {
            _deviceIds.remove(key);
            await _storage.delete(key: key);
          }
        }
      } finally {
        // Revoke the local token if the server record could not be removed.
        await _clearDeviceNotifications(revokeToken: !unregistered);
      }
    });
  }

  void expireSession() {
    if (_session == null) return;
    _session = null;
    if (_fcm.isAvailable) {
      unawaited(_enqueue(() => _clearDeviceNotifications(revokeToken: true)));
    }
  }

  Future<void> _clearDeviceNotifications({required bool revokeToken}) async {
    await Future.wait([
      _fcm.clearNotifications(),
      if (revokeToken) _fcm.deleteToken(),
    ]);
  }

  Future<void> _enqueue(Future<void> Function() operation) =>
      _work = _work.then((_) async {
        try {
          await operation();
        } catch (_) {
          debugPrint('RoomIO: Không đồng bộ được thiết bị nhận thông báo.');
        }
      });

  String _deviceKey(String accountId) => 'fcm_device_id:$accountId';

  Future<String?> _readDeviceId(String key) async =>
      _deviceIds[key] ?? await _storage.read(key: key);

  String? _readAccountId(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      // The subject scopes local storage. The API authenticates the JWT.
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final subject = claims is Map ? claims['sub'] : null;
      return subject is String && subject.isNotEmpty ? subject : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> dispose() async {
    _session = null;
    await _tokenSubscription?.cancel();
  }
}
