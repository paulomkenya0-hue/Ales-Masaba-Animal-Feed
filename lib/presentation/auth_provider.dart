import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

/// AuthProvider - Hali ya uthibitishaji wa mtumiaji katika programu nzima
class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String username, String password, {bool rememberMe = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repo.login(username, password);
      _currentUser = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_username', username); // inahitajika kwa alama ya kidole
      if (rememberMe) {
        await prefs.setBool('remember_login', true);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_login') ?? false;
    if (!remember) return null;
    return prefs.getString('saved_username');
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  /// Inaitwa baada ya alama ya kidole kuthibitishwa kwa mafanikio na BiometricHelper
  Future<bool> loginWithBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('saved_username');
    if (username == null) {
      _errorMessage = 'Ingia mara moja kwa nenosiri kabla ya kutumia alama ya kidole';
      notifyListeners();
      return false;
    }
    try {
      _currentUser = await _repo.loginWithBiometric(username);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> changePassword(String newPassword) async {
    if (_currentUser?.id == null) return false;
    await _repo.changePassword(_currentUser!.id!, newPassword);
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    if (_currentUser?.id == null) return false;
    return await _repo.verifyPin(_currentUser!.id!, pin);
  }
}
