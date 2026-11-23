class MachineModel {
  final dynamic plant;
  final dynamic fac;
  final dynamic area;
  final dynamic macId;
  final dynamic pic;

  MachineModel({this.plant, this.fac, this.area, this.macId, this.pic});

  factory MachineModel.fromJson(Map<String, dynamic> json) => MachineModel(
    plant: json['plant'],
    fac: json['fac'],
    area: json['area'],
    pic: json['pic'],
    macId: json['macId'],
  );
}
