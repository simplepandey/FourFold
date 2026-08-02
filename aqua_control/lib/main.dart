import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/devices/data/repositories/device_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OTPWidget.initializeWidget(AppConfig.msg91WidgetId, AppConfig.msg91AuthToken);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => DeviceRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(
            create: (ctx) => AuthBloc(ctx.read<AuthRepository>()),
          ),
        ],
        child: const AquaControlApp(),
      ),
    ),
  );
}
