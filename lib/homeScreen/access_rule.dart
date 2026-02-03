import 'package:chuphinh/homeScreen/patrol_home_screen.dart';

enum PatrolAction { before, after, recheck, table }

const Set<String> kPatrolRecheckUsers = {
  '22847',
  '6077',
  '22473',
  '23005',
  '30750',
  '5514',
};

class AccessRule {
  bool can(PatrolAction action, {PatrolGroup? group, required String user}) {
    if (action != PatrolAction.recheck) return true;

    if (group == PatrolGroup.Patrol) {
      return kPatrolRecheckUsers.contains(user.trim());
    }

    return true;
  }
}
