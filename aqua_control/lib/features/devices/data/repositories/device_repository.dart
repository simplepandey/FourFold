import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';

class DeviceRepository {
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  DeviceRepository() {
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
        final raw = err.response?.data?['message'] ?? err.message ?? 'Something went wrong';
        final msg = raw is List ? raw.first as String : raw as String;
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          message: msg,
        ));
      },
    ));
  }

  /// Validates that the serial number exists in module-master.
  /// Throws an exception with a human-readable message if not found.
  Future<void> validateSerialNumber(String serial) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 800));
      return; // accept any serial in mock mode
    }
    await _dio.get('${AppConfig.moduleMasterBySerial}/$serial');
  }

  /// Registers a module to the current society/user.
  Future<void> registerModule({
    required String serialNumber,
    required String registeredTo,
    required int noOfPump,
    required String phase,
    required double hpOfPump,
    required String createdBy,
  }) async {
    if (AppConfig.useMock) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    }
    await _dio.post(AppConfig.moduleRegistration, data: {
      'moduleSerialNumber': serialNumber,
      'registeredTo': registeredTo,
      'noOfPump': noOfPump,
      'phase': phase,
      'hpOfPump': hpOfPump,
      'createdBy': createdBy,
    });
  }
}
