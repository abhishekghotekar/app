/// The signed-in user returned by the Platform login API.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.status,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String status;

  String get fullName => '$firstName $lastName'.trim();

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );
}

/// The full payload returned by a successful login.
class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.publicToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String publicToken;
  final int expiresIn;
  final AuthUser user;

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        accessToken: json['access_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
        publicToken: json['public_token'] as String? ?? '',
        expiresIn: json['expires_in'] as int? ?? 0,
        user: AuthUser.fromJson(
          json['user'] as Map<String, dynamic>? ?? const {},
        ),
      );
}
