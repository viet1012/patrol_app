part of '../test.dart';


class _ReportServerMessage {
  final String? code;
  final String? message;

  const _ReportServerMessage({this.code, this.message});
}

class HseMachineInfo {
  final String plant;
  final String fac;
  final String area;
  final String macId;

  const HseMachineInfo({
    required this.plant,
    required this.fac,
    required this.area,
    required this.macId,
  });

  factory HseMachineInfo.fromJson(Map<String, dynamic> json) {
    return HseMachineInfo(
      plant: (json['plant'] ?? '').toString().trim(),
      fac: (json['fac'] ?? '').toString().trim(),
      area: (json['area'] ?? '').toString().trim(),
      macId: (json['macId'] ?? '').toString().trim(),
    );
  }
}

class QrCheckResult {
  final String? qrKey;
  final bool valid;
  final bool available;
  final bool duplicate;
  final String message;

  const QrCheckResult({
    required this.qrKey,
    required this.valid,
    required this.available,
    required this.duplicate,
    required this.message,
  });

  factory QrCheckResult.fromJson(Map<String, dynamic> json) {
    return QrCheckResult(
      qrKey: json['qrKey']?.toString().trim(),
      valid: json['valid'] == true,
      available: json['available'] == true,
      duplicate: json['duplicate'] == true,
      message: json['message']?.toString().trim() ?? '',
    );
  }
}