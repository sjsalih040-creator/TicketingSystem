class UserSession {
  final String id;
  final String username;
  final List<String> roles;
  final List<Map<String, dynamic>> warehouses;
  final bool isAdmin;

  UserSession({
    required this.id,
    required this.username,
    required this.roles,
    required this.warehouses,
    required this.isAdmin,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json['id'],
      username: json['username'],
      roles: List<String>.from(json['roles'] ?? []),
      warehouses: List<Map<String, dynamic>>.from(json['warehouses'] ?? []),
      isAdmin: json['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'roles': roles,
      'warehouses': warehouses,
      'isAdmin': isAdmin,
    };
  }
}
