import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';
import '../models/module_status_model.dart';
import '../models/module_action_log_model.dart';

class MotorRepository {
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  MotorRepository() {
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
        final raw =
            err.response?.data?['message'] ?? err.message ?? 'Command failed';
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          message: raw is List ? raw.first as String : raw as String,
        ));
      },
    ));
  }

  /// POST /motor/command  { societyCode, motorId, serialNumber, command, value?, commandBy }
  /// [command] one of TURN_ON | TURN_OFF | SET_OC | SET_UC. [value] is the threshold
  /// in amps, required for SET_OC / SET_UC.
  Future<void> sendCommand({
    required String societyCode,
    required String motorId,
    required String serialNumber,
    required String command,
    required String commandBy,
    double? value,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    await _dio.post(
      AppConfig.motorCommand,
      data: {
        'societyCode': societyCode,
        'motorId': motorId,
        'serialNumber': serialNumber,
        'command': command,
        if (value != null) 'value': value,
        'commandBy': commandBy,
      },
    );
  }

  /// GET /module-status/:serialNumber
  Future<ModuleStatusModel> fetchStatus(String serialNumber) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return ModuleStatusModel.mock(serialNumber);
    }
    final res = await _dio.get(AppConfig.moduleStatus(serialNumber));
    return ModuleStatusModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// GET /module-action-logs/:serialNumber — most recent first
  Future<List<ModuleActionLogModel>> fetchActionLogs(
      String serialNumber) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return [];
    }
    final res = await _dio.get(AppConfig.moduleActionLogs(serialNumber));
    final list = (res.data['data'] as List<dynamic>?) ?? [];
    return list
        .map((e) => ModuleActionLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
