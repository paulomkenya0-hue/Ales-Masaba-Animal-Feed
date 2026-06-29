class UserModel {
  final int? id;
  final String username;
  final String passwordHash;
  final String? fullName;
  final String role;
  final String? pinHash;
  final String? email;
  final int failedAttempts;
  final String? lockedUntil;
  final String createdAt;
  final bool isActive;

  UserModel({
    this.id,
    required this.username,
    required this.passwordHash,
    this.fullName,
    this.role = 'Admin',
    this.pinHash,
    this.email,
    this.failedAttempts = 0,
    this.lockedUntil,
    required this.createdAt,
    this.isActive = true,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int?,
        username: map['username'] as String,
        passwordHash: map['password_hash'] as String,
        fullName: map['full_name'] as String?,
        role: map['role'] as String? ?? 'Admin',
        pinHash: map['pin_hash'] as String?,
        email: map['email'] as String?,
        failedAttempts: map['failed_attempts'] as int? ?? 0,
        lockedUntil: map['locked_until'] as String?,
        createdAt: map['created_at'] as String,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'username': username,
        'password_hash': passwordHash,
        'full_name': fullName,
        'role': role,
        'pin_hash': pinHash,
        'email': email,
        'failed_attempts': failedAttempts,
        'locked_until': lockedUntil,
        'created_at': createdAt,
        'is_active': isActive ? 1 : 0,
      };
}
