import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/otp_widget/otp_widget.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  // Stored between sendOtp and verifyOtp SDK calls
  String? _reqId;

  // Stored between verifyForgotPasswordOtp and resetPassword
  String? _resetAccessToken;

  AuthRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        final msg = err.response?.data?['message'] ?? err.message ?? 'Something went wrong';
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          message: msg is List ? msg.first as String : msg as String,
        ));
      },
    ));
  }

  // ─── Login: password ─────────────────────────────────────
  Future<UserModel> loginWithPassword({
    required String mobile,
    required String password,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      await _saveSession('mock_jwt_${_mockUser.id}', _mockUser);
      return _mockUser;
    }
    final res = await _dio.post(AppConfig.userLogin, data: {
      'phoneNumber': _toE164(mobile),
      'password': password,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    final user = UserModel.fromSocietyJson(data['society'] as Map<String, dynamic>);
    await _saveSession(data['token'] as String, user);
    return user;
  }

  // ─── Login: OTP via MSG91 widget SDK ────────────────────
  Future<void> sendLoginOtp(String mobile) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 800));
      return;
    }
    final response = await OTPWidget.sendOTP({'identifier': _toMsg91(mobile)});
    final map = response as Map<dynamic, dynamic>;
    debugPrint('[MSG91 sendOTP] full response: $map');
    if (map['type'] != 'success') {
      throw Exception(map['message']?.toString() ?? 'Failed to send OTP');
    }
    _reqId = map['message']?.toString();
    debugPrint('[MSG91 sendOTP] reqId stored: $_reqId');
  }

  Future<UserModel> verifyLoginOtp({
    required String mobile,
    required String otp,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      await _saveSession('mock_jwt_${_mockUser.id}', _mockUser);
      return _mockUser;
    }
    final accessToken = await _verifyWithSdk(otp);
    final res = await _dio.post(AppConfig.verifyOtpToken, data: {
      'accessToken': accessToken,
      'phoneNumber': _toE164(mobile),
    });
    final data = res.data['data'] as Map<String, dynamic>;
    final user = UserModel.fromUserJson(data['user'] as Map<String, dynamic>);
    await _saveSession(data['token'] as String, user);
    return user;
  }

  // ─── Registration: OTP via MSG91 widget SDK ──────────────
  Future<void> sendRegistrationOtp(String mobile) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 800));
      return;
    }
    final response = await OTPWidget.sendOTP({'identifier': _toMsg91(mobile)});
    final map = response as Map<dynamic, dynamic>;
    if (map['type'] != 'success') {
      throw Exception(map['message']?.toString() ?? 'Failed to send OTP');
    }
    _reqId = map['message']?.toString();
  }

  Future<void> verifyRegistrationOtp({
    required String mobile,
    required String otp,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    }
    final accessToken = await _verifyWithSdk(otp);
    final res = await _dio.post(AppConfig.verifyOtpToken, data: {
      'accessToken': accessToken,
      'phoneNumber': _toE164(mobile),
    });
    final data = res.data['data'] as Map<String, dynamic>;
    await _storage.write(key: 'auth_token', value: data['token'] as String);
  }

  // ─── Forgot password: OTP via MSG91 widget SDK ───────────
  Future<void> sendForgotPasswordOtp(String mobile) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 800));
      return;
    }
    final response = await OTPWidget.sendOTP({'identifier': _toMsg91(mobile)});
    final map = response as Map<dynamic, dynamic>;
    if (map['type'] != 'success') {
      throw Exception(map['message']?.toString() ?? 'Failed to send OTP');
    }
    _reqId = map['message']?.toString();
  }

  Future<void> verifyForgotPasswordOtp({
    required String mobile,
    required String otp,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      _resetAccessToken = 'mock_access_token';
      return;
    }
    _resetAccessToken = await _verifyWithSdk(otp);
  }

  // POST /auth/reset-password — verifies stored accessToken, rehashes
  // password, and returns a brand-new session (JWT + user)
  Future<UserModel> resetPassword({
    required String mobile,
    required String newPassword,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      _resetAccessToken = null;
      await _saveSession('mock_jwt_${_mockUser.id}', _mockUser);
      return _mockUser;
    }
    final accessToken = _resetAccessToken;
    if (accessToken == null) {
      throw Exception('OTP not verified. Please verify OTP again.');
    }
    final res = await _dio.post(AppConfig.resetPassword, data: {
      'accessToken': accessToken,
      'phoneNumber': _toE164(mobile),
      'newPassword': newPassword,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    final user = UserModel.fromUserJson(data['user'] as Map<String, dynamic>);
    await _saveSession(data['token'] as String, user);
    _resetAccessToken = null;
    return user;
  }

  // POST /societies
  Future<UserModel> completeRegistration({
    required String mobile,
    required String name,
    required String societyName,
    required String block,
    required int totalMembers,
    required String password,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      final user = UserModel(
        id:          'usr_${DateTime.now().millisecondsSinceEpoch}',
        name:        name,
        mobile:      _toE164(mobile),
        role:        'admin',
        societyName: societyName,
        block:       block,
        societyId:   'soc_${DateTime.now().millisecondsSinceEpoch}',
        societyCode: 'SOC-MOCK01',
      );
      await _saveSession('mock_jwt_${user.id}', user);
      return user;
    }
    final res = await _dio.post(AppConfig.createSociety, data: {
      'phoneNumber':  _toE164(mobile),
      'name':         name,
      'societyName':  societyName,
      'blockOrWing':  block,
      'totalMembers': totalMembers,
      'password':     password,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    final user = UserModel(
      id:          data['id'] as String,
      name:        (data['name']        as String?) ?? name,
      mobile:      _toE164(mobile),
      role:        'admin',
      societyName: (data['societyName'] as String?) ?? societyName,
      block:       (data['blockOrWing'] as String?) ?? block,
      societyId:   data['id'] as String,
      societyCode: (data['societyCode'] as String?) ?? '',
    );
    await _storage.write(key: 'auth_user', value: jsonEncode(user.toJson()));
    return user;
  }

  // ─── Session ─────────────────────────────────────────────

  Future<UserModel?> tryRestoreSession() async {
    try {
      final token    = await _storage.read(key: 'auth_token');
      final userJson = await _storage.read(key: 'auth_user');
      if (token == null || userJson == null) return null;
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getToken() => _storage.read(key: 'auth_token');

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_user');
  }

  // ─── Helpers ─────────────────────────────────────────────

  Future<String> _verifyWithSdk(String otp) async {
    debugPrint('[MSG91 verifyOTP] reqId=$_reqId  otp=$otp');
    if (_reqId == null) throw Exception('Session expired. Please request a new OTP.');
    final response = await OTPWidget.verifyOTP({'reqId': _reqId, 'otp': otp});
    final map = response as Map<dynamic, dynamic>;
    debugPrint('[MSG91 verifyOTP] full response: $map');
    if (map['type'] != 'success') {
      throw Exception(map['message']?.toString() ?? 'Invalid OTP. Please try again.');
    }
    final token = map['message']?.toString();
    if (token == null || token.isEmpty) throw Exception('Verification failed. Please try again.');
    _reqId = null;
    return token;
  }

  Future<void> _saveSession(String token, UserModel user) async {
    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'auth_user',  value: jsonEncode(user.toJson()));
  }

  /// E.164 format: +919876543210
  static String _toE164(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return mobile;
  }

  /// MSG91 identifier format (no + prefix): 919876543210
  static String _toMsg91(String mobile) => _toE164(mobile).replaceFirst('+', '');

  // ─── Mock data ────────────────────────────────────────────

  static const _mockUser = UserModel(
    id:          'usr_mock_001',
    name:        'Navin Bind',
    mobile:      AppConfig.mockPhone,
    role:        'admin',
    societyName: 'Green Valley Society',
    block:       'Block 4',
    societyId:   'soc_mock_001',
    societyCode: 'SOC-MOCK01',
  );
}
