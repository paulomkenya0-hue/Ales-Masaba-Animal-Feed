import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;
  bool get isCashier => _currentUser?.isCashier ?? false;

  Future<bool> login(String username, String password,
      {bool rememberMe = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repo.login(username, password);
      _currentUser = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_username', username);
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

  Future<void> logout() async {
    await _repo.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Mtumiaji aliyeingia anabadilisha password yake mwenyewe
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) return false;
    try {
      await _repo.changePassword(_currentUser!.username, oldPassword, newPassword);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    if (_currentUser?.id == null) return false;
    return await _repo.verifyPin(_currentUser!.id!, pin);
  }

  Future<void> setPin(String pin) async {
    if (_currentUser?.id == null) return;
    await _repo.setPin(_currentUser!.id!, pin);
  }

  // -----------------------------------------------------------------
  // Usimamizi wa Cashier (Super Admin pekee)
  // -----------------------------------------------------------------

  Future<UserModel?> registerCashier({
    required String username,
    required String password,
    required String branchName,
    String? fullName,
  }) async {
    if (_currentUser?.uid == null) {
      _errorMessage = 'Lazima uwe umeingia kama Msimamizi Mkuu';
      notifyListeners();
      return null;
    }
    try {
      return await _repo.registerCashier(
        username: username,
        password: password,
        branchName: branchName,
        fullName: fullName,
        createdByUid: _currentUser!.uid!,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Stream<List<UserModel>> watchCashiers() => _repo.watchCashiers();

  Future<bool> setCashierActive(String uid, bool isActive) async {
    try {
      await _repo.setCashierActive(uid, isActive);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateCashierBranch(String uid, String branchName) async {
    try {
      await _repo.updateCashierBranch(uid, branchName);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeCashierPassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _repo.changeCashierPassword(
        username: username,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
