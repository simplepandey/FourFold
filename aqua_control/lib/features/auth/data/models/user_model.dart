import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.mobile,
    required super.role,
    required super.societyName,
    required super.block,
  });

  // Parses the `user` object returned by POST /auth/verify-otp
  // { id, phoneNumber, isVerified, name }
  factory UserModel.fromUserJson(Map<String, dynamic> json) => UserModel(
        id:          json['id'] as String,
        name:        (json['name'] as String?) ?? '',
        mobile:      json['phoneNumber'] as String,
        role:        'member',
        societyName: '',
        block:       '',
      );

  // Parses the `society` object returned by POST /auth/society-login
  // { id, phoneNumber, name, societyName, blockOrWing, totalMembers }
  factory UserModel.fromSocietyJson(Map<String, dynamic> json) => UserModel(
        id:          json['id'] as String,
        name:        (json['name'] as String?) ?? '',
        mobile:      json['phoneNumber'] as String,
        role:        'admin',
        societyName: (json['societyName'] as String?) ?? '',
        block:       (json['blockOrWing'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'role': role,
        'societyName': societyName,
        'block': block,
      };
}
