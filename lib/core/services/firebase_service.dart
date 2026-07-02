import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// FirebaseService - Kiunganishi kikuu cha Firebase (Auth + Firestore)
///
/// Muundo wa Firestore:
///   users/{uid}        -> username, email(bandia), role, branchName, fullName,
///                          isActive, createdAt, createdBy
///
/// "email(bandia)" - Firebase Auth inahitaji email kimuundo, lakini programu
/// inatumia Username/Password pekee (kama ilivyoombwa). Tunatengeneza email
/// ya ndani kiotomatiki: "<username>@ales-masaba.app" - haitumiki kutuma
/// email yoyote, ni kitambulisho cha ndani cha Firebase Auth pekee.
class FirebaseService {
  FirebaseService._();

  static const String _emailDomain = 'ales-masaba.app';
  static const String usersCollection = 'users';

  /// Jina la App ya pili (secondary) inayotumika Super Admin anapotengeneza
  /// akaunti mpya ya Cashier - hii inazuia Super Admin asitolewe nje
  /// (auto sign-out) wakati akaunti mpya inapoundwa, kwa sababu Firebase
  /// Auth SDK huweka session ya mtumiaji wa mwisho aliyeundwa kama "current user".
  static const String _adminAppName = 'ales_masaba_admin_secondary';

  static bool _initialized = false;

  /// Anzisha Firebase mara moja tu wakati app inaanza (kwenye main.dart)
  static Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();

    // Wezesha Firestore offline persistence - hii ndiyo inayowezesha
    // "Offline + Online Sync": data inasomwa/inaandikwa kwenye cache ya
    // ndani ya kifaa wakati hakuna intaneti, kisha inasawazishwa (sync)
    // kiotomatiki mara intaneti inaporudi.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    _initialized = true;
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get usersRef =>
      firestore.collection(usersCollection);

  /// Badilisha "username" (Jina la Mtumiaji) kuwa email ya ndani ya Firebase Auth
  static String usernameToEmail(String username) =>
      '${username.trim().toLowerCase()}@$_emailDomain';

  /// Pata (au tengeneza) FirebaseApp ya pili - inatumika kwa vitendo vya
  /// kiutawala (kutengeneza/kusimamia Cashier) bila kuathiri session ya
  /// Super Admin aliyeko kwenye app kuu.
  static Future<FirebaseApp> _getAdminApp() async {
    try {
      return Firebase.app(_adminAppName);
    } catch (_) {
      final defaultApp = Firebase.app();
      return await Firebase.initializeApp(
        name: _adminAppName,
        options: defaultApp.options,
      );
    }
  }

  /// Futa session ya App ya pili baada ya kumaliza kazi ya kiutawala
  /// (haiathiri Super Admin aliyeko kwenye app kuu)
  static Future<void> resetAdminApp() async {
    try {
      final app = Firebase.app(_adminAppName);
      final secondaryAuth = FirebaseAuth.instanceFor(app: app);
      await secondaryAuth.signOut();
    } catch (_) {
      // Haipo bado - hakuna cha kufanya
    }
  }

  static Future<FirebaseAuth> adminAuth() async {
    final app = await _getAdminApp();
    return FirebaseAuth.instanceFor(app: app);
  }
}
