class User {
  final String id;
  final String email;
  final String name;
  final String? shortName;
  final String? phone;
  final String? profilePicture;
  final bool isAdmin;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.shortName,
    this.phone,
    this.profilePicture,
    required this.isAdmin,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      shortName: json['shortName'],
      phone: json['phone'],
      profilePicture: json['profilePicture'],
      isAdmin: json['isAdmin'] ?? false,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'shortName': shortName,
      'phone': phone,
      'profilePicture': profilePicture,
      'isAdmin': isAdmin,
      'isActive': isActive,
    };
  }
}
