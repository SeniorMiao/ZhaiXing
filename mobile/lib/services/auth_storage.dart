import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kToken = 'access_token';

class AuthStorage {
  AuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) => _storage.write(key: _kToken, value: token);

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<void> clearToken() => _storage.delete(key: _kToken);
}
