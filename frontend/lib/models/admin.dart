class Admin {
  final int id;
  final String username;
  final String email;
  final bool isActive;
  final bool isSuperAdmin;

  Admin({
    required this.id,
    required this.username,
    required this.email,
    required this.isActive,
    required this.isSuperAdmin,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isActive: json['is_active'] ?? true,
      isSuperAdmin: json['is_super_admin'] ?? false,
    );
  }
}
