// Act4 Enhancement 3: model for the signed-in user. It is built both from the
// /auth/login response and from the map UserService rebuilds out of
// SharedPreferences, which is what lets the profile render offline.

class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;
  final String accessToken;
  final String refreshToken;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.image,
    required this.accessToken,
    required this.refreshToken,
  });

  // Both shapes use the same key names, so only the defaults differ from a
  // plain mapping: a value missing from either source becomes empty rather
  // than null, so the UI never has to null-check a field.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      gender: json['gender'] ?? '',
      image: json['image'] ?? '',
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}
