import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';
import '../models/device_model.dart';
import '../models/device_info_model.dart';

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
    ));
  }

  /// Validates that the serial number exists in module-master.
  Future<void> validateSerialNumber(String serial) async {
    try {
      await _dio.get('${AppConfig.deviceRegister}/$serial');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Registers a module to the current user/society.
  Future<void> registerModule({
    required String serialNumber,
    required String societyCode,
    required int noOfPump,
    required String phase,
    required double hpOfPump,
    required String address,
    required String wingBlock,
    required String pincode,
    required String district,
    required String createdBy,
    String? userId,
    String state = 'Maharashtra',
    String country = 'India',
  }) async {
    try {
      await _dio.post(AppConfig.moduleRegistration, data: {
        'serialNumber': serialNumber,
        'societyCode':  societyCode,
        'noOfPump':     noOfPump,
        'phase':        phase,
        'hpOfPump':     hpOfPump,
        'address':      address,
        'wingBlock':    wingBlock,
        'pincode':      pincode,
        'district':     district,
        'state':        state,
        'country':      country,
        'createdBy':    createdBy,
        if (userId != null) 'userId': userId,
      });
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Fetches full device info (ESP MQTT topics, module config, members) by serial number.
  Future<DeviceInfoModel> fetchDeviceInfo(String serialNumber) async {
    try {
      final res = await _dio.get('${AppConfig.deviceInfo}/$serialNumber');
      return DeviceInfoModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Fetches all modules registered to this user.
  Future<List<DeviceModel>> fetchDevices(String userId) async {
    try {
      final res = await _dio.get(AppConfig.userModules(userId));
      final list = res.data['data'] as List<dynamic>;
      return list
          .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Exception _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final raw = e.response?.data?['message'];
    final apiMsg = raw is List
        ? (raw.first as String)
        : (raw as String?) ?? '';

    return switch (statusCode) {
      404 => Exception('Serial number not found. Check the label on your device.'),
      409 => Exception('This device is already registered to a society.'),
      401 => Exception('Session expired. Please log in again.'),
      400 => _map400Error(apiMsg),
      _ => Exception(apiMsg.isNotEmpty ? apiMsg : (e.message ?? 'Something went wrong. Please try again.')),
    };
  }

  Exception _map400Error(String apiMsg) {
    final lower = apiMsg.toLowerCase();
    if (lower.contains('not active')) {
      return Exception("Device hasn't been activated yet. Contact support.");
    }
    if (lower.contains('society')) {
      return Exception('Please create or join a society before adding a device.');
    }
    return Exception(apiMsg.isNotEmpty ? apiMsg : 'Invalid request. Please try again.');
  }
}
