import 'package:equatable/equatable.dart';

class DeviceModel extends Equatable {
  final String espId;
  final String productCode;
  final String name;
  final String societyCode;
  final String role;
  final String serialHash;
  final String address;

  const DeviceModel({
    required this.espId,
    required this.productCode,
    required this.name,
    required this.societyCode,
    required this.role,
    required this.serialHash,
    this.address = '',
  });

  bool get isAdmin => role == 'admin';

  /// Falls back to the product code if a name was never set (shouldn't
  /// happen once registered through the app, but the API field is nullable).
  String get displayName => name.trim().isNotEmpty ? name : productCode;

  String get displaySubtitle {
    final addr = address.trim();
    if (addr.isNotEmpty) {
      return addr.length > 15 ? '${addr.substring(0, 15)}…' : addr;
    }
    return societyCode;
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    final esp    = (json['esp']    as Map<String, dynamic>?) ?? {};
    final module = (json['module'] as Map<String, dynamic>?) ?? {};
    final addr   = (json['address'] as String?)
        ?? (module['address'] as String?)
        ?? '';
    return DeviceModel(
      espId:        (esp['id']            as String?) ?? '',
      productCode:  (json['productCode']  as String?) ?? '',
      name:         (json['name']         as String?) ?? '',
      societyCode:  (json['societyCode']  as String?) ?? '',
      role:         (json['role']         as String?) ?? 'member',
      serialHash:   (esp['serialHash']    as String?) ?? '',
      address:      addr,
    );
  }

  @override
  List<Object?> get props => [espId, productCode];
}