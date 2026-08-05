import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

// ─── Login states ─────────────────────────────────────────────

class LoginOtpSent extends AuthState {
  final String mobile;
  const LoginOtpSent(this.mobile);
  @override
  List<Object?> get props => [mobile];
}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

// ─── Forgot password states ────────────────────────────────────

/// OTP sent to mobile — show OTP input step
class ForgotPasswordOtpSent extends AuthState {
  final String mobile;
  const ForgotPasswordOtpSent(this.mobile);
  @override
  List<Object?> get props => [mobile];
}

/// OTP verified — show new-password step
class ForgotPasswordOtpVerified extends AuthState {
  final String mobile;
  const ForgotPasswordOtpVerified(this.mobile);
  @override
  List<Object?> get props => [mobile];
}

// ─── Registration states ──────────────────────────────────────

/// OTP sent to mobile — show OTP input step
class RegistrationOtpSent extends AuthState {
  final String mobile;
  const RegistrationOtpSent(this.mobile);
  @override
  List<Object?> get props => [mobile];
}

/// OTP verified — show details form step
class RegistrationOtpVerified extends AuthState {
  final String mobile;
  const RegistrationOtpVerified(this.mobile);
  @override
  List<Object?> get props => [mobile];
}

// ─── Error ────────────────────────────────────────────────────

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}
