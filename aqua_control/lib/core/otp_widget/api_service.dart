import 'api_urls.dart';
import 'http_request.dart';

class ApiService {
  static Future<Map<String, dynamic>> sendOTP(Map<String, dynamic> body) async {
    try {
      return await otpHttpRequest(ApiUrls.sendOTP, body, isPost: true);
    } catch (e) {
      throw Exception('Error sending OTP: $e');
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(Map<String, dynamic> body) async {
    try {
      return await otpHttpRequest(ApiUrls.verifyOTP, body, isPost: true);
    } catch (e) {
      throw Exception('Error verifying OTP: $e');
    }
  }

  static Future<Map<String, dynamic>> retryOTP(Map<String, dynamic> body) async {
    try {
      return await otpHttpRequest(ApiUrls.retryOTP, body, isPost: true);
    } catch (e) {
      throw Exception('Error retrying OTP: $e');
    }
  }

  static Future<Map<String, dynamic>> getWidgetProcess(String widgetId, String tokenAuth) async {
    try {
      final url = ApiUrls.getWidgetProcess(widgetId, tokenAuth);
      return await otpHttpRequest(url, const {}, isPost: false);
    } catch (e) {
      throw Exception('Error getting widget process: $e');
    }
  }
}
