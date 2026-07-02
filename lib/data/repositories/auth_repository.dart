import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import '../../core/services/firebase_service.dart';

/// AuthRepository - Firebase Auth (Super Admin/Cashier) + Firestore (roles)
/// + SQLite (cache ya ndani kwa ajili ya Offline Login halisi).
///
/// MUHIMU KUHUSU OFFLINE:
/// Firebase Auth SDK yenyewe HUWEZI ku-login mtumiaji kutoka mwanzo bila
/// intaneti (inahitaji mtandao mara ya kwanza kuthibitisha). Ili programu
/// iendelee kufanya kazi Offline (kama mahitaji yanavyotaka), tunahifadhi
/// "cache" ya ndani (SQLite) ya jina la mtumiaji + password hash + role kila
/// mara mtumiaji anapo-login akiwa Online kwa mafanikio. Akiwa Offline baadaye,
/// anaweza kuendelea kuingia kwa kutumia cache hiyo (kama ilivyo desturi ya
/// mifumo ya POS ya offline-first).
class AuthRepository {
  final dbHelper = DatabaseHelper.instance;
  static const int maxAttempts = 5;
  static const int lockMinutes = 5;

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  // ---------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------

  Future<UserModel> login(String username, String password) async {
    final cleanUsername = username.trim();

    // Kama kuna akaunti ya ndani (SQLite) isiyo na Firebase uid bado
    // (mfano: 'admin' ya kwanza kabisa iliyowekwa wakati wa usanikishaji),
    // na password inalingana, tunaijaribu "bootstrap" kuwa Super Admin
    // halisi wa Firebase - hii inafanyika mara moja tu, kwa akaunti ya
    // kwanza pekee.
    final bootstrapped = await _tryBootstrapLocalAdmin(cleanUsername, password);
    if (bootstrapped != null) return bootstrapped;

    try {
      // 1) Jaribu Firebase Auth (Online)
      final cred = await FirebaseService.auth.signInWithEmailAndPassword(
        email: FirebaseService.usernameToEmail(cleanUsername),
        password: password,
      );

      final uid = cred.user!.uid;
      final doc = await FirebaseService.usersRef.doc(uid).get();
      if (!doc.exists) {
        throw Exception('Wasifu wa mtumiaji haukupatikana kwenye mfumo');
      }
      final data = doc.data()!;
      if (data['isActive'] == false) {
        await FirebaseService.auth.signOut();
        throw Exception('Akaunti hii imezimwa. Wasiliana na Msimamizi Mkuu.');
      }

      final user = UserModel.fromFirestore(uid, data, passwordHash: _hash(password));

      // Sasisha cache ya ndani kwa ajili ya Offline Login ijayo
      final localId = await _cacheUserLocally(user);
      return user.copyWith(id: localId);
    } on FirebaseAuthException catch (e) {
      if (_isNetworkError(e)) {
        // 2) Hakuna intaneti - jaribu Offline Login kwa kutumia cache ya ndani
        return await _offlineLogin(cleanUsername, password);
      }
      throw Exception(_mapFirebaseError(e));
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('network')) {
        return await _offlineLogin(cleanUsername, password);
      }
      rethrow;
    }
  }

  bool _isNetworkError(FirebaseAuthException e) =>
      e.code == 'network-request-failed';

  /// Ikiwa kuna mtumiaji wa ndani (SQLite) mwenye password sahihi lakini
  /// hana Firebase uid bado (yaani hajawahi kusawazishwa), tunamtengenezea
  /// akaunti halisi ya Firebase Auth + Firestore (Super Admin). Ikiwa hakuna
  /// mtandao wakati huu, tunamruhusu aingie Offline bila kubadilisha chochote
  /// (itajaribu tena bootstrap mara mtandao utakaporudi).
  Future<UserModel?> _tryBootstrapLocalAdmin(String username, String password) async {
    final db = await dbHelper.database;
    final rows = await db.query('users',
        where: 'username = ? AND (uid IS NULL OR uid = "")', whereArgs: [username]);
    if (rows.isEmpty) return null;

    final local = UserModel.fromMap(rows.first);
    if (local.passwordHash != _hash(password)) return null; // acha login ya kawaida ikague hitilafu
    if (!local.isActive) throw Exception('Akaunti hii imezimwa. Wasiliana na Msimamizi Mkuu.');

    try {
      final cred = await FirebaseService.auth.createUserWithEmailAndPassword(
        email: FirebaseService.usernameToEmail(username),
        password: password,
      );
      final uid = cred.user!.uid;
      final userData = {
        'username': username,
        'fullName': local.fullName,
        'role': local.role,
        'branchName': local.branchName,
        'email': FirebaseService.usernameToEmail(username),
        'isActive': true,
        'createdAt': local.createdAt,
      };
      await FirebaseService.usersRef.doc(uid).set(userData);

      final db2 = await dbHelper.database;
      await db2.update('users', {'uid': uid}, where: 'id = ?', whereArgs: [local.id]);

      return local.copyWith(uid: uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Tayari ipo Firebase (labda imeundwa awali) - jaribu login ya kawaida badala yake
        return null;
      }
      if (_isNetworkError(e)) {
        // Hakuna mtandao - ruhusu Offline login kwa kutumia rekodi ya ndani kama ilivyo
        return local;
      }
      rethrow;
    } catch (_) {
      // Hitilafu nyingine yoyote ya mtandao - ruhusu Offline login
      return local;
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-email':
        return 'Jina la mtumiaji au nenosiri si sahihi';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Jina la mtumiaji au nenosiri si sahihi';
      case 'user-disabled':
        return 'Akaunti hii imezimwa. Wasiliana na Msimamizi Mkuu.';
      case 'too-many-requests':
        return 'Majaribio mengi yameshindwa. Jaribu tena baadaye.';
      default:
        return 'Imeshindikana kuingia: ${e.message ?? e.code}';
    }
  }

  Future<UserModel> _offlineLogin(String username, String password) async {
    final db = await dbHelper.database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);

    if (rows.isEmpty) {
      throw Exception(
          'Huna mtandao na hakuna taarifa za kuingia zilizohifadhiwa kwenye kifaa hiki. Unganisha intaneti mara ya kwanza.');
    }

    final cached = UserModel.fromMap(rows.first);

    if (cached.lockedUntil != null) {
      final lockedUntil = DateTime.tryParse(cached.lockedUntil!);
      if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
        final remaining = lockedUntil.difference(DateTime.now()).inMinutes + 1;
        throw Exception('Akaunti imefungwa. Subiri dakika $remaining kisha jaribu tena.');
      }
    }

    if (!cached.isActive) {
      throw Exception('Akaunti hii imezimwa. Wasiliana na Msimamizi Mkuu.');
    }

    if (cached.passwordHash != _hash(password)) {
      await _registerFailedAttempt(cached);
      throw Exception('Jina la mtumiaji au nenosiri si sahihi');
    }

    await db.update('users', {'failed_attempts': 0, 'locked_until': null},
        where: 'id = ?', whereArgs: [cached.id]);

    return cached;
  }

  Future<void> _registerFailedAttempt(UserModel cached) async {
    final db = await dbHelper.database;
    final newAttempts = cached.failedAttempts + 1;
    String? lockedUntil;
    if (newAttempts >= maxAttempts) {
      lockedUntil = DateTime.now().add(const Duration(minutes: lockMinutes)).toIso8601String();
    }
    await db.update(
      'users',
      {'failed_attempts': newAttempts, if (lockedUntil != null) 'locked_until': lockedUntil},
      where: 'id = ?',
      whereArgs: [cached.id],
    );
    if (lockedUntil != null) {
      throw Exception('Majaribio mengi yameshindwa. Akaunti imefungwa kwa dakika $lockMinutes.');
    }
  }

Future<int> _cacheUserLocally(UserModel user) async {
  final db = await dbHelper.database;

  // Tafuta kwa uid AU username
  final existing = await db.query(
    'users',
    where: 'uid = ? OR username = ?',
    whereArgs: [user.uid, user.username],
  );

  final map = user.toMap()..remove('id');

  if (existing.isEmpty) {
    return await db.insert('users', map);
  } else {
    final localId = existing.first['id'] as int;

    await db.update(
      'users',
      map,
      where: 'id = ?',
      whereArgs: [localId],
    );

    return localId;
  }
}
  /// Inatumika BAADA YA alama ya kidole kuthibitishwa na mfumo wa simu (local_auth).
  Future<UserModel> loginWithBiometric(String username) async {
    final db = await dbHelper.database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (rows.isEmpty) {
      throw Exception('Mtumiaji hajapatikana');
    }
    return UserModel.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------
  // USAJILI WA CASHIER (Super Admin pekee)
  // ---------------------------------------------------------------------

  /// Super Admin anasajili Cashier mpya: Branch/Station Name + Username +
  /// Password (fixed). Inatumia FirebaseApp ya pili ili Super Admin
  /// asitolewe nje (asi-sign-out) wakati akaunti mpya inapoundwa.
  Future<UserModel> registerCashier({
    required String username,
    required String password,
    required String branchName,
    String? fullName,
    required String createdByUid,
  }) async {
    final secondaryAuth = await FirebaseService.adminAuth();
    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: FirebaseService.usernameToEmail(username),
        password: password,
      );
      final uid = cred.user!.uid;

      final userData = {
        'username': username.trim(),
        'fullName': fullName,
        'role': AppRole.cashier,
        'branchName': branchName,
        'email': FirebaseService.usernameToEmail(username),
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': createdByUid,
      };
      await FirebaseService.usersRef.doc(uid).set(userData);

      final user = UserModel.fromFirestore(uid, userData, passwordHash: _hash(password));
      final localId = await _cacheUserLocally(user);
      return user.copyWith(id: localId);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Jina la mtumiaji tayari linatumika. Chagua lingine.');
      }
      if (e.code == 'weak-password') {
        throw Exception('Nenosiri ni fupi mno. Tumia angalau herufi 6.');
      }
      throw Exception('Imeshindikana kusajili Cashier: ${e.message ?? e.code}');
    } finally {
      // Safisha session ya app ya pili (haiathiri Super Admin wa app kuu)
      await FirebaseService.resetAdminApp();
    }
  }

  /// Orodha ya Cashier/maduka yote (Super Admin pekee)
  Stream<List<UserModel>> watchCashiers() {
    return FirebaseService.usersRef
        .where('role', isEqualTo: AppRole.cashier)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Super Admin anazima/anawasha akaunti ya Cashier
  Future<void> setCashierActive(String uid, bool isActive) async {
    await FirebaseService.usersRef.doc(uid).update({'isActive': isActive});
    final db = await dbHelper.database;
    await db.update('users', {'is_active': isActive ? 1 : 0},
        where: 'uid = ?', whereArgs: [uid]);
  }

  /// Super Admin anabadilisha jina la tawi/duka la Cashier
  Future<void> updateCashierBranch(String uid, String branchName) async {
    await FirebaseService.usersRef.doc(uid).update({'branchName': branchName});
    final db = await dbHelper.database;
    await db.update('users', {'branch_name': branchName},
        where: 'uid = ?', whereArgs: [uid]);
  }

  /// Super Admin anabadilisha password ya Cashier. Kwa sababu Firebase Auth
  /// (bila Cloud Functions/Admin SDK) inahitaji password ya sasa ili
  /// kuithibitisha, Super Admin lazima aingize password ya zamani ya Cashier
  /// (aliyoipanga mwenyewe wakati wa usajili, kwa vile ni "fixed password").
  /// TAARIFA: Awamu ijayo tunaweza kuongeza Cloud Function (Admin SDK) ili
  /// Super Admin abadilishe password bila kujua ya zamani.
  Future<void> changeCashierPassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    final secondaryAuth = await FirebaseService.adminAuth();
    try {
      final cred = await secondaryAuth.signInWithEmailAndPassword(
        email: FirebaseService.usernameToEmail(username),
        password: oldPassword,
      );
      await cred.user!.updatePassword(newPassword);

      final db = await dbHelper.database;
      await db.update('users', {'password_hash': _hash(newPassword)},
          where: 'username = ?', whereArgs: [username]);
    } on FirebaseAuthException catch (e) {
      throw Exception('Imeshindikana kubadilisha password: ${_mapFirebaseError(e)}');
    } finally {
      await FirebaseService.resetAdminApp();
    }
  }

  // ---------------------------------------------------------------------
  // MTUMIAJI MWENYEWE (Super Admin au Cashier anayeingia)
  // ---------------------------------------------------------------------

  Future<void> changePassword(String username, String oldPassword, String newPassword) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) throw Exception('Hujaingia kwenye mfumo');

    final cred = EmailAuthProvider.credential(
      email: FirebaseService.usernameToEmail(username),
      password: oldPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);

    final db = await dbHelper.database;
    await db.update('users', {'password_hash': _hash(newPassword)},
        where: 'uid = ?', whereArgs: [user.uid]);
  }

  Future<void> setPin(int localUserId, String pin) async {
    final db = await dbHelper.database;
    await db.update('users', {'pin_hash': _hash(pin)}, where: 'id = ?', whereArgs: [localUserId]);
  }

  Future<bool> verifyPin(int localUserId, String pin) async {
    final db = await dbHelper.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [localUserId]);
    if (rows.isEmpty) return false;
    final storedHash = rows.first['pin_hash'] as String?;
    if (storedHash == null) return false;
    return storedHash == _hash(pin);
  }

  Future<void> signOut() async {
    await FirebaseService.auth.signOut();
  }
}
