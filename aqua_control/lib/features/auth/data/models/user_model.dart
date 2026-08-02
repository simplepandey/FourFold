import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.mobile,
    required super.role,
    required super.societyName,
    required super.block,
    required super.societyId,
    super.societyCode = '',
  });

  // Restores a previously-serialised UserModel from secure storage.
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:          json['id'] as String,
        name:        json['name'] as String,
        mobile:      json['mobile'] as String,
        role:        json['role'] as String,
        societyName: json['societyName'] as String,
        block:       json['block'] as String,
        societyId:   (json['societyId'] as String?) ?? '',
        societyCode: (json['societyCode'] as String?) ?? '',
      );

  // Parses the `user` object returned by POST /auth/verify-otp
  // { id, phoneNumber, isVerified, name, societyId?, societyCode?, societyName?, blockOrWing?, role? }
  factory UserModel.fromUserJson(Map<String, dynamic> json) => UserModel(
        id:          json['id'] as String,
        name:        (json['name'] as String?) ?? '',
        mobile:      json['phoneNumber'] as String,
        role:        (json['role'] as String?) ?? 'member',
        societyName: (json['societyName'] as String?) ?? '',
        block:       (json['blockOrWing'] as String?) ?? '',
        societyId:   (json['societyId'] as String?) ?? '',
        societyCode: (json['societyCode'] as String?) ?? '',
      );

  // Parses the `society` object returned by POST /auth/user-login
  // { id, userId, societyCode, phoneNumber, name, societyName, blockOrWing, totalMembers }
  factory UserModel.fromSocietyJson(Map<String, dynamic> json) => UserModel(
        id:          (json['userId'] as String?) ?? json['id'] as String,
        name:        (json['name'] as String?) ?? '',
        mobile:      json['phoneNumber'] as String,
        role:        'admin',
        societyName: (json['societyName'] as String?) ?? '',
        block:       (json['blockOrWing'] as String?) ?? '',
        societyId:   json['id'] as String,
        societyCode: (json['societyCode'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'role': role,
        'societyName': societyName,
        'block': block,
        'societyId': societyId,
        'societyCode': societyCode,
      };
}
