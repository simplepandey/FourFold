enum AppEnv { local, dev, prod }

abstract class _EnvConfig {
  String get baseUrl;
  String get userLogin;
  String get verifyOtpToken;
  String get resetPassword;
  String get createSociety;
  String get deviceRegister;
  String get deviceInfo;
  String get moduleRegistration;
  String get motorCommand;
  String societyMembers(String societyId);
}

class _LocalConfig extends _EnvConfig {
  @override
  String get baseUrl => 'http://192.168.1.7:3000/api/v1';
  @override
  String get userLogin => '/auth/user-login';
  @override
  String get verifyOtpToken => '/auth/verify-otp-token';
  @override
  String get resetPassword => '/auth/reset-password';
  @override
  String get createSociety => '/societies';
  @override
  String get deviceRegister => '/device/register';
  @override
  String get deviceInfo => '/device/info';
  @override
  String get moduleRegistration => '/module-registration';
  @override
  String get motorCommand => '/motor/command';
  @override
  String societyMembers(String societyId) => '/societies/$societyId/members';
}

class _DevConfig extends _EnvConfig {
  @override
  String get baseUrl => 'https://dev-api.aquacontrol.in/api/v1';
  @override
  String get userLogin => '/auth/user-login';
  @override
  String get verifyOtpToken => '/auth/verify-otp-token';
  @override
  String get resetPassword => '/auth/reset-password';
  @override
  String get createSociety => '/societies';
  @override
  String get deviceRegister => '/device/register';
  @override
  String get deviceInfo => '/device/info';
  @override
  String get moduleRegistration => '/module-registration';
  @override
  String get motorCommand => '/motor/command';
  @override
  String societyMembers(String societyId) => '/societies/$societyId/members';
}

class _ProdConfig extends _EnvConfig {
  @override
  String get baseUrl => 'https://api.fourfoldsystem.com/api/v1';
  @override
  String get userLogin => '/auth/user-login';
  @override
  String get verifyOtpToken => '/auth/verify-otp-token';
  @override
  String get resetPassword => '/auth/reset-password';
  @override
  String get createSociety => '/societies';
  @override
  String get deviceRegister => '/device/register';
  @override
  String get deviceInfo => '/device/info';
  @override
  String get moduleRegistration => '/module-registration';
  @override
  String get motorCommand => '/motor/command';
  @override
  String societyMembers(String societyId) => '/societies/$societyId/members';
}

class AppConfig {
  AppConfig._();

  // ─── MSG91 widget credentials ─────────────────────────────
  static const String msg91WidgetId = '3668616c4c50393534343631';
  static const String msg91AuthToken = '556358Tm54jk2S6a6de516P1';

  static const String _envName =
      String.fromEnvironment('APP_ENV', defaultValue: 'local');

  static AppEnv get env => switch (_envName) {
        'dev' => AppEnv.dev,
        'prod' => AppEnv.prod,
        _ => AppEnv.local,
      };

  static bool get useMock => false;

  static _EnvConfig get _config => switch (env) {
        AppEnv.local => _LocalConfig(),
        AppEnv.dev => _DevConfig(),
        AppEnv.prod => _ProdConfig(),
      };

  static String get baseUrl => _config.baseUrl;
  static String get userLogin => _config.userLogin;
  static String get verifyOtpToken => _config.verifyOtpToken;
  static String get resetPassword => _config.resetPassword;
  static String get createSociety => _config.createSociety;
  static String get deviceRegister => _config.deviceRegister;
  static String get deviceInfo => _config.deviceInfo;
  static String userModules(String userId) => '/device/user-modules/$userId';
  static String get moduleRegistration => _config.moduleRegistration;
  static String get motorCommand => _config.motorCommand;
  static String moduleStatus(String productCode) =>
      '/module-status/$productCode';
  static String moduleActionLogs(String productCode) =>
      '/module-action-logs/$productCode';
  static String societyMembers(String societyId) =>
      _config.societyMembers(societyId);

  static const String mockPhone = '+919876543210';
}
