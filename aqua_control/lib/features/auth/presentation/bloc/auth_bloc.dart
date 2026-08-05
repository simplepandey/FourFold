import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  AuthBloc(this._repo) : super(const AuthInitial()) {
    // App startup
    on<AppStarted>(_onAppStarted);
    // Login
    on<LoginWithPassword>(_onLoginWithPassword);
    on<SendLoginOtp>(_onSendLoginOtp);
    on<VerifyLoginOtp>(_onVerifyLoginOtp);
    // Forgot password
    on<SendForgotPasswordOtp>(_onSendForgotPasswordOtp);
    on<VerifyForgotPasswordOtp>(_onVerifyForgotPasswordOtp);
    on<ResetPassword>(_onResetPassword);
    // Registration
    on<SendRegistrationOtp>(_onSendRegistrationOtp);
    on<VerifyRegistrationOtp>(_onVerifyRegistrationOtp);
    on<CompleteRegistration>(_onCompleteRegistration);
    // Shared
    on<LogoutRequested>(_onLogout);
  }

  // ─── App startup ────────────────────────────────────────────

  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<AuthState> emit,
  ) async {
    final user = await _repo.tryRestoreSession();
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  // ─── Login ──────────────────────────────────────────────────

  Future<void> _onLoginWithPassword(
    LoginWithPassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.loginWithPassword(
        mobile: event.mobile,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  Future<void> _onSendLoginOtp(
    SendLoginOtp event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.sendLoginOtp(event.mobile);
      emit(LoginOtpSent(event.mobile));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  Future<void> _onVerifyLoginOtp(
    VerifyLoginOtp event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.verifyLoginOtp(
        mobile: event.mobile,
        otp: event.otp,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  // ─── Forgot password ──────────────────────────────────────────

  Future<void> _onSendForgotPasswordOtp(
    SendForgotPasswordOtp event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.sendForgotPasswordOtp(event.mobile);
      emit(ForgotPasswordOtpSent(event.mobile));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  Future<void> _onVerifyForgotPasswordOtp(
    VerifyForgotPasswordOtp event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.verifyForgotPasswordOtp(
        mobile: event.mobile,
        otp: event.otp,
      );
      emit(ForgotPasswordOtpVerified(event.mobile));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  Future<void> _onResetPassword(
    ResetPassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.resetPassword(
        mobile: event.mobile,
        newPassword: event.newPassword,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  // ─── Registration ────────────────────────────────────────────

  Future<void> _onSendRegistrationOtp(
    SendRegistrationOtp event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.sendRegistrationOtp(event.mobile);
      emit(RegistrationOtpSent(event.mobile));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  Future<void> _onVerifyRegistrationOtp(
    VerifyRegistrationOtp event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.verifyRegistrationOtp(
        mobile: event.mobile,
        otp: event.otp,
      );
      emit(RegistrationOtpVerified(event.mobile));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  Future<void> _onCompleteRegistration(
    CompleteRegistration event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.completeRegistration(
        mobile: event.mobile,
        name: event.name,
        societyName: event.societyName,
        block: event.block,
        totalMembers: event.totalMembers,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthFailure(_message(e)));
    }
  }

  // ─── Shared ──────────────────────────────────────────────────

  Future<void> _onLogout(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }

  String _message(Object e) {
    if (e is DioException) return e.message ?? 'Something went wrong';
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return e.toString();
  }
}
