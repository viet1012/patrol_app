import 'package:chuphinh/core/models/auth_me.dart';
import 'package:chuphinh/core/models/patrol_group.dart';

/// Quyền của user trên một [PatrolGroup], tính sẵn từ [AuthMe].
class GroupAccess {
  final bool before;
  final bool after;
  final bool recheck;
  final bool summary;

  const GroupAccess({
    this.before = false,
    this.after = false,
    this.recheck = false,
    this.summary = false,
  });

  static const none = GroupAccess();

  bool get any => before || after || recheck || summary;

  bool can(PatrolAction action) {
    switch (action) {
      case PatrolAction.before:
        return before;
      case PatrolAction.after:
        return after;
      case PatrolAction.recheck:
        return recheck;
      case PatrolAction.summary:
        return summary;
    }
  }

  factory GroupAccess.of(AuthMe? me, PatrolGroup group) {
    if (me == null) return none;

    return GroupAccess(
      before: me.can(group, PatrolAction.before),
      after: me.can(group, PatrolAction.after),
      recheck: me.can(group, PatrolAction.recheck),
      summary: me.can(group, PatrolAction.summary),
    );
  }

  /// Quyền mọi group; `me == null` -> tất cả [none].
  static Map<PatrolGroup, GroupAccess> mapOf(AuthMe? me) => {
    for (final group in PatrolGroup.values) group: GroupAccess.of(me, group),
  };
}
