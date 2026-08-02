import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(const AppStarted());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthUnauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.primary.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.water_drop, color: c.primary, size: 44),
              ),
              const SizedBox(height: 24),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  children: [
                    TextSpan(text: 'Aqua', style: TextStyle(color: c.textPrimary)),
                    TextSpan(text: 'Control', style: TextStyle(color: c.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'SMART WATER MANAGEMENT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 2.0),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: c.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}