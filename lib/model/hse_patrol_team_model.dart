class HsePatrolTeamModel {
  final int no;
  final String? plant;
  final String? grp;
  final String? pic1;
  final String? pic2;
  final String? pic3;
  final String? pic4;
  final String? pic5;
  final String? pic6;
  final String? pic7;
  final String? pic8;
  final String? pic9;
  final String? pic10;
  final String? note;

  HsePatrolTeamModel({
    required this.no,
    this.plant,
    this.grp,
    this.pic1,
    this.pic2,
    this.pic3,
    this.pic4,
    this.pic5,
    this.pic6,
    this.pic7,
    this.pic8,
    this.pic9,
    this.pic10,
    this.note,
  });

  factory HsePatrolTeamModel.fromJson(Map<String, dynamic> json) {
    return HsePatrolTeamModel(
      no: json['no'],
      plant: json['plant'],
      grp: json['grp'],
      pic1: json['pic1'],
      pic2: json['pic2'],
      pic3: json['pic3'],
      pic4: json['pic4'],
      pic5: json['pic5'],
      pic6: json['pic6'],
      pic7: json['pic7'],
      pic8: json['pic8'],
      pic9: json['pic9'],
      pic10: json['pic10'],
      note: json['note'],
    );
  }
}
