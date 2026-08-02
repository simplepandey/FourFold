import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/main/presentation/screens/main_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/module_detail_screen.dart';
import '../../features/home/presentation/screens/activity_history_screen.dart';
import '../../features/devices/data/models/device_model.dart';
import '../../features/devices/presentation/screens/devices_screen.dart';
import '../../features/devices/presentation/screens/add_device_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/members_screen.dart';
import '../../features/motor_settings/presentation/screens/motor_settings_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => HomeScreen(),
              routes: [
                GoRoute(
                  path: 'module-detail',
                  builder: (context, state) => ModuleDetailScreen(
                    device: state.extra as DeviceModel,
                  ),
                  routes: [
                    GoRoute(
                      path: 'history',
                      builder: (context, state) => ActivityHistoryScreen(
                        serialNumber: state.extra as String,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'motor-settings',
                  builder: (context, state) => const MotorSettingsScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/devices',
              builder: (context, state) => const DevicesScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const AddDeviceScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'members',
                  builder: (context, state) => MembersScreen(
                    societyId: state.extra as String,
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
}
