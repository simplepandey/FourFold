import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';
import '../models/society_member_model.dart';

class SocietyRepository {
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  SocietyRepository() {
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
        final raw = err.response?.data?['message'] ?? err.message ?? 'Request failed';
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          message: raw is List ? raw.first as String : raw as String,
        ));
      },
    ));
  }

  /// POST /societies/:societyId/members
  /// [phoneNumber] must be E.164 (+919876543210) — auto-converted if 10-digit Indian number.
  /// [name] is optional.
  Future<void> addMember({
    required String societyId,
    required String phoneNumber,
    String? name,
    String? serialNumber,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 700));
      return;
    }
    await _dio.post(
      AppConfig.societyMembers(societyId),
      data: {
        'phoneNumber': _toE164(phoneNumber),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (serialNumber != null && serialNumber.trim().isNotEmpty) 'serialNumber': serialNumber.trim(),
      },
    );
  }

  /// GET /societies/:societyId/members
  Future<List<SocietyMemberModel>> getMembers(String societyId) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      return SocietyMemberModel.mock;
    }
    final res = await _dio.get(AppConfig.societyMembers(societyId));
    final list = (res.data['data'] as List<dynamic>?) ?? [];
    return list.map((e) => SocietyMemberModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PUT /societies/:societyId/members/:memberId  { role }
  Future<SocietyMemberModel> updateMemberRole({
    required String societyId,
    required String memberId,
    required String role,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      final m = SocietyMemberModel.mock.firstWhere((m) => m.id == memberId);
      return m.copyWith(role: role);
    }
    final res = await _dio.put(
      AppConfig.societyMember(societyId, memberId),
      data: {'role': role},
    );
    return SocietyMemberModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// DELETE /societies/:societyId/members/:memberId
  Future<void> deleteMember({
    required String societyId,
    required String memberId,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }
    await _dio.delete(AppConfig.societyMember(societyId, memberId));
  }

  static String _toE164(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return mobile;
  }
}