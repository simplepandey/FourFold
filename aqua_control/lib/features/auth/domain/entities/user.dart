import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String name;
  final String mobile;
  final String role; // 'admin' | 'member'
  final String societyName;
  final String block;
  final String societyId; // UUID of the society (used for /societies/:id API calls)
  final String societyCode; // SOC-XXXXX code (used for module registration)

  const User({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.societyName,
    required this.block,
    required this.societyId,
    this.societyCode = '',
  });

  bool get isAdmin => role == 'admin';

  @override
  List<Object?> get props => [id, mobile];
}

