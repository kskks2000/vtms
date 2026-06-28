/// 로그인 사용자 정보.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    this.roles = const [],
    this.permissions = const [],
  });

  final int id;
  final String email;
  final String fullName;
  final bool isActive;
  final List<String> roles;
  final List<String> permissions;

  bool hasRole(String code) => roles.contains(code);
  bool can(String permission) => permissions.contains(permission);

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      roles: (json['roles'] as List?)?.map((e) => e as String).toList() ?? const [],
      permissions:
          (json['permissions'] as List?)?.map((e) => e as String).toList() ??
              const [],
    );
  }
}

/// API 호출 실패를 표현하는 예외. 사용자에게 보여줄 메시지를 담는다.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
