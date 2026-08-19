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
      // GET /module-status/:productCode blocks server-side for up to 30s
      // (ModuleStatusService.HEARTBEAT_TIMEOUT_MS) — it pings the device for
      // a heartbeat and sends zero bytes back until it settles. On Flutter
      // Web, Dio's browser adapter has no separate TCP-connect phase, so
      // connectTimeout effectively bounds the whole no-data wait — it must
      // stay above the backend's 30s too, not just receiveTimeout, or a
      // real 200 with correct data gets thrown away as a client timeout.
      connectTimeout: const Duration(seconds: 40),
      receiveTimeout: const Duration(seconds: 40),
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

  /// POST /motor/command  { societyCode, motorId, productCode, command, value?, commandBy }
  /// [command] one of TURN_ON | TURN_OFF | SET_OC | SET_UC. [value] is the threshold
  /// in amps, required for SET_OC / SET_UC.
  Future<void> sendCommand({
    required String societyCode,
    required String motorId,
    required String productCode,
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
        'productCode': productCode,
        'command': command,
        if (value != null) 'value': value,
        'commandBy': commandBy,
      },
    );
  }

  /// GET /module-status/:productCode
  Future<ModuleStatusModel> fetchStatus(String productCode) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return ModuleStatusModel.mock(productCode);
    }
    final res = await _dio.get(AppConfig.moduleStatus(productCode));
    return ModuleStatusModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// GET /module-action-logs/:productCode — most recent first
  Future<List<ModuleActionLogModel>> fetchActionLogs(
      String productCode) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return [];
    }
    final res = await _dio.get(AppConfig.moduleActionLogs(productCode));
    final list = (res.data['data'] as List<dynamic>?) ?? [];
    return list
        .map((e) => ModuleActionLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
