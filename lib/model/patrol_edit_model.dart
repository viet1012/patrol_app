class PatrolEditDTO {
  final String comment;
  final String countermeasure;
  final String editUser;

  PatrolEditDTO({
    required this.comment,
    required this.countermeasure,
    required this.editUser,
  });

  Map<String, dynamic> toJson() => {
    'comment': comment,
    'countermeasure': countermeasure,
    'editUser': editUser,
  };
}
