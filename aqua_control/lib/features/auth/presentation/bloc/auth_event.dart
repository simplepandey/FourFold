import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

// ─── Login ────────────────────────────────────────────────────

class LoginWithPassword extends AuthEvent {
  final String mobile;
  final String password;
  const LoginWithPassword(this.mobile, this.password);
  @override
  List<Object?> get props => [mobile, password];
}

class SendLoginOtp extends AuthEvent {
  final String mobile;
  const SendLoginOtp(this.mobile);
  @override
  List<Object?> get props => [mobile];
}

class VerifyLoginOtp extends AuthEvent {
  final String mobile;
  final String otp;
  const VerifyLoginOtp(this.mobile, this.otp);
  @override
  List<Object?> get props => [mobile, otp];
}

// ─── Registration ─────────────────────────────────────────────

class SendRegistrationOtp extends AuthEvent {
  final String mobile;
  const SendRegistrationOtp(this.mobile);
  @override
  List<Object?> get props => [mobile];
}

class VerifyRegistrationOtp extends AuthEvent {
  final String mobile;
  final String otp;
  const VerifyRegistrationOtp(this.mobile, this.otp);
  @override
  List<Object?> get props => [mobile, otp];
}

class CompleteRegistration extends AuthEvent {
  final String mobile;
  final String name;
  final String societyName;
  final String block;
  final int totalMembers;
  final String password;

  const CompleteRegistration({
    required this.mobile,
    required this.name,
    required this.societyName,
    required this.block,
    required this.totalMembers,
    required this.password,
  });

  @override
  List<Object?> get props => [mobile, name, societyName];
}

// ─── Shared ───────────────────────────────────────────────────

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
