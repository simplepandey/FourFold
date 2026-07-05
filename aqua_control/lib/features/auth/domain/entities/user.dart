import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String name;
  final String mobile;
  final String role; // 'admin' | 'member'
  final String societyName;
  final String block;

  const User({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.societyName,
    required this.block,
  });

  bool get isAdmin => role == 'admin';

  @override
  List<Object?> get props => [id, mobile];
}
