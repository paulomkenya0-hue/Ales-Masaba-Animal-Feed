/// Roles za mfumo - zinazolingana na mahitaji: Super Admin na Cashier
class AppRole {
  static const String superAdmin = 'super_admin';
  static const String cashier = 'cashier';
}

class UserModel {
  /// id ya ndani (SQLite cache) - inatumika kwa foreign keys za mauzo n.k.
  /// hadi Awamu 2 (uhamishaji wa data ya biashara kwenda Firestore) ikamilike.
  final int? id;

  /// Firebase Auth UID - kitambulisho halisi cha kudumu cha mtumiaji
  final String? uid;

  final String username;
  final String passwordHash;
  final String? fullName;
  final String role;
  final String? branchName;
  final String? pinHash;
  final String? email;
  final int failedAttempts;
  final String? lockedUntil;
  final String createdAt;
  final bool isActive;

  UserModel({
    this.id,
    this.uid,
    required this.username,
    required this.passwordHash,
    this.fullName,
    this.role = AppRole.superAdmin,
    this.branchName,
    this.pinHash,
    this.email,
    this.failedAttempts = 0,
    this.lockedUntil,
    required this.createdAt,
    this.isActive = true,
  });

  bool get isSuperAdmin => role == AppRole.superAdmin;
  bool get isCashier => role == AppRole.cashier;

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int?,
        uid: map['uid'] as String?,
        username: map['username'] as String,
        passwordHash: map['password_hash'] as String,
        fullName: map['full_name'] as String?,
        role: map['role'] as String? ?? AppRole.superAdmin,
        branchName: map['branch_name'] as String?,
        pinHash: map['pin_hash'] as String?,
        email: map['email'] as String?,
        failedAttempts: map['failed_attempts'] as int? ?? 0,
        lockedUntil: map['locked_until'] as String?,
        createdAt: map['created_at'] as String,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  /// Kutoka Firestore doc (users/{uid})
  factory UserModel.fromFirestore(String uid, Map<String, dynamic> data,
      {int? localId, String passwordHash = ''}) {
    return UserModel(
      id: localId,
      uid: uid,
      username: data['username'] as String? ?? '',
      passwordHash: passwordHash,
      fullName: data['fullName'] as String?,
      role: data['role'] as String? ?? AppRole.cashier,
      branchName: data['branchName'] as String?,
      email: data['email'] as String?,
      createdAt: data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
        'username': username,
        'fullName': fullName,
        'role': role,
        'branchName': branchName,
        'email': email,
        'isActive': isActive,
        'createdAt': createdAt,
      };

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uid': uid,
        'username': username,
        'password_hash': passwordHash,
        'full_name': fullName,
        'role': role,
        'branch_name': branchName,
        'pin_hash': pinHash,
        'email': email,
        'failed_attempts': failedAttempts,
        'locked_until': lockedUntil,
        'created_at': createdAt,
        'is_active': isActive ? 1 : 0,
      };

  UserModel copyWith({int? id, String? uid, String? passwordHash}) => UserModel(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        username: username,
        passwordHash: passwordHash ?? this.passwordHash,
        fullName: fullName,
        role: role,
        branchName: branchName,
        pinHash: pinHash,
        email: email,
        failedAttempts: failedAttempts,
        lockedUntil: lockedUntil,
        createdAt: createdAt,
        isActive: isActive,
      );
}
