class PatrolExportQuery {
  final String? plant;
  final String? division;
  final String? area;
  final String? machine;
  final String? type;
  final String? afStatus;
  final String? grp;
  final String? pic;
  final String? patrolUser;
  final String? qrKey;

  const PatrolExportQuery({
    this.plant,
    this.division,
    this.area,
    this.machine,
    this.type,
    this.afStatus,
    this.grp,
    this.pic,
    this.patrolUser,
    this.qrKey,
  });

  /// ✅ FROM MAP (backend query params)
  factory PatrolExportQuery.fromMap(Map<String, String> map) {
    return PatrolExportQuery(
      plant: map['plant'],
      division: map['division'],
      area: map['area'],
      machine: map['machine'],
      type: map['type'],
      afStatus: map['afStatus'],
      grp: map['grp'],
      pic: map['pic'],
      patrolUser: map['patrolUser'],
      qrKey: map['qrKey'],
    );
  }

  Map<String, String> toQueryParams() {
    final m = <String, String>{};

    void put(String k, String? v) {
      if (v != null && v.trim().isNotEmpty) {
        m[k] = v.trim();
      }
    }

    put('plant', plant);
    put('division', division);
    put('area', area);
    put('machine', machine);
    put('type', type);
    put('afStatus', afStatus);
    put('grp', grp);
    put('pic', pic);
    put('patrolUser', patrolUser);
    put('qrKey', qrKey);

    return m;
  }
}
