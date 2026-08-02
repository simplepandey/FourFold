class SocietyMemberModel {
  final String id;
  final String societyId;
  final String phoneNumber;
  final String? userId;
  final String role;
  final DateTime joinedAt;

  const SocietyMemberModel({
    required this.id,
    required this.societyId,
    required this.phoneNumber,
    this.userId,
    required this.role,
    required this.joinedAt,
  });

  bool get isAdmin => role == 'admin';

  factory SocietyMemberModel.fromJson(Map<String, dynamic> json) => SocietyMemberModel(
        id:          json['id'] as String,
        societyId:   (json['societyId'] ?? json['societyCode'] ?? '') as String,
        phoneNumber: json['phoneNumber'] as String,
        userId:      json['userId'] as String?,
        role:        json['role'] as String? ?? 'member',
        joinedAt:    DateTime.parse(json['joinedAt'] as String),
      );

  SocietyMemberModel copyWith({String? role}) => SocietyMemberModel(
        id:          id,
        societyId:   societyId,
        phoneNumber: phoneNumber,
        userId:      userId,
        role:        role ?? this.role,
        joinedAt:    joinedAt,
      );

  static List<SocietyMemberModel> mock = [
    SocietyMemberModel(id: 'm1', societyId: 's1', phoneNumber: '+919876543210', role: 'admin',  joinedAt: DateTime(2026, 1, 1)),
    SocietyMemberModel(id: 'm2', societyId: 's1', phoneNumber: '+919876543211', role: 'member', joinedAt: DateTime(2026, 2, 15)),
    SocietyMemberModel(id: 'm3', societyId: 's1', phoneNumber: '+919876543212', role: 'member', joinedAt: DateTime(2026, 3, 10)),
    SocietyMemberModel(id: 'm4', societyId: 's1', phoneNumber: '+919123456789', role: 'member', joinedAt: DateTime(2026, 4, 20)),
  ];
}