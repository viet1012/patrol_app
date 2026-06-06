import '../homeScreen/patrol_home_screen.dart';

class AuthMe {
  final String empId;
  final String role;
  final String? plant;

  final Map<String, Map<String, bool>> permissions;

  AuthMe({
    required this.empId,
    required this.role,
    required this.permissions,
    this.plant,
  });

  bool can(PatrolGroup group, PatrolAction action) {
    final g = permissions[group.name];
    if (g == null) return false;

    final key = action.name;
    return g[key] ?? false;
  }

  factory AuthMe.fromJson(Map<String, dynamic> json) {
    final raw = json['permissions'];

    final perms = <String, Map<String, bool>>{};

    if (raw is Map<String, dynamic>) {
      raw.forEach((k, v) {
        if (v is Map) {
          perms[k] = Map<String, bool>.from(v);
        }
      });
    }

    return AuthMe(
      empId: json['empId']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      plant: json['plant']?.toString().trim(),
      permissions: perms,
    );
  }
}
