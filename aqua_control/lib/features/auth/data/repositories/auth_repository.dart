import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

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
  // POST /auth/society-login  { phoneNumber, password }
  // response: { data: { society: {...}, token } }

  Future<UserModel> loginWithPassword({
    required String mobile,
    required String password,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      return _mockUser;
    }
    final res = await _dio.post(AppConfig.societyLogin, data: {
      'phoneNumber': _toE164(mobile),
      'password': password,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    await _storage.write(key: 'auth_token', value: data['token'] as String);
    return UserModel.fromSocietyJson(data['society'] as Map<String, dynamic>);
  }

  // ─── Login: OTP ───────────────────────────────────────────
  // POST /auth/send-otp  { phoneNumber }

  Future<void> sendLoginOtp(String mobile) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 800));
      return;
    }
    await _dio.post(AppConfig.sendOtp, data: {'phoneNumber': _toE164(mobile)});
  }

  // POST /auth/verify-otp  { phoneNumber, otp }
  // response: { data: { user: {...}, token } }

  Future<UserModel> verifyLoginOtp({
    required String mobile,
    required String otp,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      return _mockUser;
    }
    final res = await _dio.post(AppConfig.verifyOtp, data: {
      'phoneNumber': _toE164(mobile),
      'otp': otp,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    await _storage.write(key: 'auth_token', value: data['token'] as String);
    return UserModel.fromUserJson(data['user'] as Map<String, dynamic>);
  }

  // ─── Registration: OTP ────────────────────────────────────
  // Reuses the same send-otp / verify-otp endpoints

  Future<void> sendRegistrationOtp(String mobile) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 800));
      return;
    }
    await _dio.post(AppConfig.sendOtp, data: {'phoneNumber': _toE164(mobile)});
  }

  Future<void> verifyRegistrationOtp({
    required String mobile,
    required String otp,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      if (otp != AppConfig.mockOtp) throw Exception('Invalid OTP');
      return;
    }
    // verify-otp returns a JWT — save it so the subsequent POST /societies call
    // is authenticated (the endpoint requires Bearer token)
    final res = await _dio.post(AppConfig.verifyOtp, data: {
      'phoneNumber': _toE164(mobile),
      'otp': otp,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    await _storage.write(key: 'auth_token', value: data['token'] as String);
  }

  // POST /societies  { phoneNumber, name, societyName, blockOrWing, totalMembers, password }
  // Requires JWT saved during verifyRegistrationOtp
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
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        mobile: _toE164(mobile),
        role: 'admin',
        societyName: societyName,
        block: block,
      );
      await _storage.write(key: 'auth_token', value: 'mock_jwt_${user.id}');
      return user;
    }
    final res = await _dio.post(AppConfig.createSociety, data: {
      'phoneNumber': _toE164(mobile),
      'name': name,
      'societyName': societyName,
      'blockOrWing': block,        // backend field name
      'totalMembers': totalMembers,
      'password': password,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    // Society create response has no token — token was already saved in verifyRegistrationOtp
    return UserModel(
      id:          data['id'] as String,
      name:        (data['name'] as String?) ?? name,
      mobile:      _toE164(mobile),
      role:        'admin',
      societyName: (data['societyName'] as String?) ?? societyName,
      block:       (data['blockOrWing'] as String?) ?? block,
    );
  }

  // ─── Shared ───────────────────────────────────────────────

  Future<String?> getToken() => _storage.read(key: 'auth_token');

  Future<void> logout() => _storage.delete(key: 'auth_token');

  // ─── Helpers ─────────────────────────────────────────────

  // Converts 10-digit Indian number to E.164.
  // Already formatted numbers are returned as-is.
  static String _toE164(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return mobile; // already E.164 or unknown format
  }

  // ─── Mock data ────────────────────────────────────────────

  static const _mockUser = UserModel(
    id: 'usr_mock_001',
    name: 'Navin Bind',
    mobile: AppConfig.mockPhone,
    role: 'admin',
    societyName: 'Green Valley Society',
    block: 'Block 4',
  );
}
