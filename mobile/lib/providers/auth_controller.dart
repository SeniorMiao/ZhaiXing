import 'package:flutter/foundation.dart';

import '../models/api_models.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._storage) {
    api = ApiService(tokenGetter: () => _token);
  }

  final AuthStorage _storage;
  late final ApiService api;

  String? _token;
  UserInfo? user;
  bool bootstrapped = false;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> bootstrap() async {
    _token = await _storage.readToken();
    if (_token != null && _token!.isNotEmpty) {
      try {
        user = await api.me();
      } catch (_) {
        _token = null;
        await _storage.clearToken();
        user = null;
      }
    }
    bootstrapped = true;
    notifyListeners();
  }

  Future<void> applyAuth(AuthResult result) async {
    _token = result.accessToken;
    user = result.user;
    await _storage.saveToken(_token!);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    user = null;
    await _storage.clearToken();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (!isLoggedIn) return;
    try {
      user = await api.me();
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  void applyUserInfo(UserInfo u) {
    user = u;
    notifyListeners();
  }
}
