import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../models/user_model.dart';

/// AuthRepository - Husimamia uthibitishaji wa mtumiaji (Login, PIN, Lock)
class AuthRepository {
  final dbHelper = DatabaseHelper.instance;
  static const int maxAttempts = 5;
  static const int lockMinutes = 5;

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  /// Inarudisha UserModel ikiwa imefanikiwa, au inatupa Exception na ujumbe wa Kiswahili
  Future<UserModel> login(String username, String password) async {
    final db = await dbHelper.database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);

    if (rows.isEmpty) {
      throw Exception('Jina la mtumiaji au nenosiri si sahihi');
    }

    final user = UserModel.fromMap(rows.first);

    // Angalia kama akaunti imefungwa
    if (user.lockedUntil != null) {
      final lockedUntil = DateTime.tryParse(user.lockedUntil!);
      if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
        final remaining = lockedUntil.difference(DateTime.now()).inMinutes + 1;
        throw Exception('Akaunti imefungwa. Subiri dakika $remaining kisha jaribu tena.');
      }
    }

    if (user.passwordHash != _hash(password)) {
      final newAttempts = user.failedAttempts + 1;
      String? lockedUntil;
      if (newAttempts >= maxAttempts) {
        lockedUntil = DateTime.now().add(const Duration(minutes: lockMinutes)).toIso8601String();
      }
      await db.update(
        'users',
        {'failed_attempts': newAttempts, if (lockedUntil != null) 'locked_until': lockedUntil},
        where: 'id = ?',
        whereArgs: [user.id],
      );
      if (lockedUntil != null) {
        throw Exception('Majaribio mengi yameshindwa. Akaunti imefungwa kwa dakika $lockMinutes.');
      }
      throw Exception('Jina la mtumiaji au nenosiri si sahihi');
    }

    // Mafanikio: weka upya majaribio
    await db.update(
      'users',
      {'failed_attempts': 0, 'locked_until': null},
      where: 'id = ?',
      whereArgs: [user.id],
    );

    return user;
  }

  /// Inatumika BAADA YA alama ya kidole kuthibitishwa na mfumo wa simu (local_auth).
  /// Hatuhitaji nenosiri tena kwa sababu kifaa chenyewe kimethibitisha mwenye akaunti.
  Future<UserModel> loginWithBiometric(String username) async {
    final db = await dbHelper.database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (rows.isEmpty) {
      throw Exception('Mtumiaji hajapatikana');
    }
    return UserModel.fromMap(rows.first);
  }

  Future<void> changePassword(int userId, String newPassword) async {
    final db = await dbHelper.database;
    await db.update(
      'users',
      {'password_hash': _hash(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> setPin(int userId, String pin) async {
    final db = await dbHelper.database;
    await db.update('users', {'pin_hash': _hash(pin)}, where: 'id = ?', whereArgs: [userId]);
  }

  Future<bool> verifyPin(int userId, String pin) async {
    final db = await dbHelper.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return false;
    final storedHash = rows.first['pin_hash'] as String?;
    if (storedHash == null) return false;
    return storedHash == _hash(pin);
  }
}
