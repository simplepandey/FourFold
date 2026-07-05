enum AppEnv { local1, local }

class AppConfig {
  AppConfig._();

  // Change to AppEnv.local to hit the real backend
  static AppEnv env = AppEnv.local1;

  static bool get useMock => env == AppEnv.local1;

  // Backend: NestJS on :3000, global prefix /api, URI version /v1
  static String get baseUrl => switch (env) {
        AppEnv.local1 => '',
        AppEnv.local  => 'http://localhost:3000/api/v1',
      };

  // ─── Endpoints ────────────────────────────────────────────
  static const String sendOtp      = '/auth/send-otp';
  static const String verifyOtp    = '/auth/verify-otp';
  static const String societyLogin = '/auth/society-login';
  static const String createSociety = '/societies';
  static const String moduleMasterBySerial = '/module-master/serial-number';
  static const String moduleRegistration   = '/module-registration';

  // ─── Mock credentials (shown as hints in UI) ──────────────
  static const String mockPhone = '+919876543210';
  static const String mockOtp   = '123456';
}
