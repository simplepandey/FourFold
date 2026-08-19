class MqttTopics {
  final String commands;
  final String telemetry;
  final String alert;
  final String heartbeat;

  const MqttTopics({
    required this.commands,
    required this.telemetry,
    required this.alert,
    required this.heartbeat,
  });

  factory MqttTopics.fromJson(Map<String, dynamic> json) => MqttTopics(
        commands:  json['commands']  as String,
        telemetry: json['telemetry'] as String,
        alert:     json['alert']     as String,
        heartbeat: json['heartbeat'] as String,
      );
}

class EspInfo {
  final String id;
  final String serialNumber;
  final String serialHash;
  final String productCode;
  final MqttTopics topics;

  const EspInfo({
    required this.id,
    required this.serialNumber,
    required this.serialHash,
    required this.productCode,
    required this.topics,
  });

  factory EspInfo.fromJson(Map<String, dynamic> json) => EspInfo(
        id:           json['id']           as String,
        serialNumber: json['serialNumber'] as String,
        serialHash:   json['serialHash']   as String,
        productCode:  json['productCode']  as String,
        topics:       MqttTopics.fromJson(json['topics'] as Map<String, dynamic>),
      );
}

class ModuleInfo {
  final String id;
  final String productCode;
  final String registeredTo;
  final String name;
  final int noOfPump;
  final String phase;
  final double hpOfPump;
  final String address;
  final String wingBlock;
  final String pincode;
  final String district;
  final String state;
  final String country;
  final String createdBy;

  const ModuleInfo({
    required this.id,
    required this.productCode,
    required this.name,
    required this.registeredTo,
    required this.noOfPump,
    required this.phase,
    required this.hpOfPump,
    required this.address,
    required this.wingBlock,
    required this.pincode,
    required this.district,
    required this.state,
    required this.country,
    required this.createdBy,
  });

  factory ModuleInfo.fromJson(Map<String, dynamic> json) => ModuleInfo(
        id:           json['id']           as String,
        productCode:  json['productCode']  as String,
        name:         (json['name']        as String?) ?? '',
        registeredTo: json['registeredTo'] as String,
        noOfPump:     json['noOfPump']     as int,
        phase:        json['phase']        as String,
        hpOfPump:     (json['hpOfPump']   as num).toDouble(),
        address:      (json['address']    as String?) ?? '',
        wingBlock:    (json['wingBlock']  as String?) ?? '',
        pincode:      (json['pincode']    as String?) ?? '',
        district:     (json['district']   as String?) ?? '',
        state:        (json['state']      as String?) ?? '',
        country:      (json['country']    as String?) ?? '',
        createdBy:    (json['createdBy']  as String?) ?? '',
      );
}

class DeviceMemberModel {
  final String id;
  final String phoneNumber;
  final String? userId;
  final String? productCode;
  final String role;

  bool get isAdmin => role == 'admin';

  const DeviceMemberModel({
    required this.id,
    required this.phoneNumber,
    this.userId,
    this.productCode,
    required this.role,
  });

  factory DeviceMemberModel.fromJson(Map<String, dynamic> json) => DeviceMemberModel(
        id:          json['id']          as String,
        phoneNumber: json['phoneNumber'] as String,
        userId:      json['userId']      as String?,
        productCode: json['productCode'] as String?,
        role:        json['role']        as String,
      );
}

class DeviceInfoModel {
  final EspInfo? esp;
  final ModuleInfo? module;
  final List<DeviceMemberModel> members;

  const DeviceInfoModel({
    this.esp,
    this.module,
    required this.members,
  });

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) => DeviceInfoModel(
        esp:     json['esp']    != null
            ? EspInfo.fromJson(json['esp']    as Map<String, dynamic>)
            : null,
        module:  json['module'] != null
            ? ModuleInfo.fromJson(json['module'] as Map<String, dynamic>)
            : null,
        members: ((json['members'] as List<dynamic>?) ?? [])
            .map((e) => DeviceMemberModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}