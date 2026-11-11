import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;
  final void Function()? onSessionChanged;

  SecureStorageService(this._storage, {this.onSessionChanged});

  static const _tokenKey = 'access_token';
  static const _rfTokenKey = 'refresh_token';
  static const _roleKey = 'role';

  Future<void> saveTokens({
    required String accessToken,
    required String rfToken,
    required String role,
  }) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _rfTokenKey, value: rfToken);
    await _storage.write(key: _roleKey, value: role);
    onSessionChanged?.call();
  }

  Future<String?> getAccessToken() => _storage.read(key: _tokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _rfTokenKey);
  Future<String?> getRole() => _storage.read(key: _roleKey);

  Future<void> clearAll() async {
    onSessionChanged?.call();
    await _storage.deleteAll();
  }

  Future<void> deleteAccessToken() async {
    onSessionChanged?.call();
    await _storage.delete(key: _tokenKey);
  }

  Future<void> deleteRefreshToken() => _storage.delete(key: _rfTokenKey);
  Future<void> deleteRole() => _storage.delete(key: _roleKey);

  // Refreshing the access token keeps the same account and shared feature state.
  Future<void> saveAccessToken(String accessToken) =>
      _storage.write(key: _tokenKey, value: accessToken);
}
