import '../homeScreen/patrol_home_screen.dart';

class AuthMe {
  final String empId;
  final String role;
  final Map<String, Map<String, bool>> permissions;

  AuthMe({required this.empId, required this.role, required this.permissions});

  bool can(PatrolGroup group, PatrolAction action) {
    final g = permissions[group.name];
    if (g == null) return false;

    final key = action.name; // before / after / recheck / summary
    return g[key] ?? false;
  }

  factory AuthMe.fromJson(Map<String, dynamic> json) {
    final raw = json['permissions'] as Map<String, dynamic>;
    final perms = <String, Map<String, bool>>{};

    raw.forEach((k, v) {
      perms[k] = Map<String, bool>.from(v);
    });

    return AuthMe(empId: json['empId'], role: json['role'], permissions: perms);
  }
}
