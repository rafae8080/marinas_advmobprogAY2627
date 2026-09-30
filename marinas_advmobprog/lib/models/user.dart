// Act4 Enhancement 3: model for the signed-in user. It is built both from the
// /auth/login response and from the map UserService rebuilds out of
// SharedPreferences, which is what lets the profile render offline.

// Act5 Enhancement 2: which backend the session came from. The profile uses it
// to decide which details and account actions to show.
enum LoginType {
  dummyJson,
  firebase;

  String get label => this == LoginType.firebase ? 'Firebase' : 'DummyJSON';

  static LoginType fromName(String? name) => LoginType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => LoginType.dummyJson,
  );
}

class User {
  final int id;
  // Act5 Enhancement 2: Firebase ids are strings, so they live beside the
  // numeric DummyJSON id instead of replacing it.
  final String uid;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;
  final int age;
  final String phone;
  final LoginType loginType;
  final String accessToken;
  final String refreshToken;

  const User({
    required this.id,
    required this.uid,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.image,
    required this.age,
    required this.phone,
    required this.loginType,
    required this.accessToken,
    required this.refreshToken,
  });

  // Both shapes use the same key names, so only the defaults differ from a
  // plain mapping: a value missing from either source becomes empty rather
  // than null, so the UI never has to null-check a field.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : 0,
      uid: json['uid'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      gender: json['gender'] ?? '',
      image: json['image'] ?? '',
      age: json['age'] is int ? json['age'] : 0,
      phone: json['phone'] ?? '',
      loginType: LoginType.fromName(json['loginType']),
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
    );
  }

  // Act5 Enhancement 2: the document stored in Firestore under users/{uid}.
  // Tokens are deliberately left out — they only belong on the device.
  Map<String, dynamic> toProfileJson() => {
    'uid': uid,
    'username': username,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'age': age,
    'phone': phone,
  };

  bool get isFirebase => loginType == LoginType.firebase;

  bool get hasSession => id != 0 || uid.isNotEmpty;

  String get fullName => '$firstName $lastName'.trim();
}
