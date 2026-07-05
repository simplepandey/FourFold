import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aqua_control/app.dart';
import 'package:aqua_control/core/theme/theme_cubit.dart';
import 'package:aqua_control/features/auth/data/repositories/auth_repository.dart';
import 'package:aqua_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aqua_control/features/devices/data/repositories/device_repository.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
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

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}