import 'api_service.dart';

/// MSG91 widget OTP client. Vendored from `sendotp_flutter_sdk` v0.0.2 with the
/// networking layer fixed — see `http_request_io.dart` for why.
class OTPWidget {
  static String _widgetId = '';
  static String _tokenAuth = '';

  static bool _checkInitialization() {
    if (_widgetId.isEmpty || _tokenAuth.isEmpty) {
      // ignore: avoid_print
      print('Widget not initialized. Call initializeWidget before using any method.');
      return false;
    }
    return true;
  }

  static void initializeWidget(String widgetId, String tokenAuth) {
    _widgetId = widgetId;
    _tokenAuth = tokenAuth;
  }

  /// identifier (string, mandatory) — email or mobile number (country code, no +).
  static Future<Map<String, dynamic>?> sendOTP(Map<String, dynamic> body) async {
    if (!_checkInitialization()) return null;
    final payload = {'widgetId': _widgetId, 'tokenAuth': _tokenAuth, ...body};
    try {
      return await ApiService.sendOTP(payload);
    } catch (error) {
      throw Exception('Error exception OTP: $error');
    }
  }

  static Future<Map<String, dynamic>?> verifyOTP(Map<String, dynamic> body) async {
    if (!_checkInitialization()) return null;
    final payload = {'widgetId': _widgetId, 'tokenAuth': _tokenAuth, ...body};
    try {
      return await ApiService.verifyOTP(payload);
    } catch (error) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> retryOTP(Map<String, dynamic> body) async {
    if (!_checkInitialization()) return null;
    final payload = {'widgetId': _widgetId, 'tokenAuth': _tokenAuth, ...body};
    try {
      return await ApiService.retryOTP(payload);
    } catch (error) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getWidgetProcess() async {
    if (!_checkInitialization()) return null;
    try {
      return await ApiService.getWidgetProcess(_widgetId, _tokenAuth);
    } catch (error) {
      rethrow;
    }
  }
}
