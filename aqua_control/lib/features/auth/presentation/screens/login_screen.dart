import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: c.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 56),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: c.primary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.water_drop, color: c.primary, size: 40),
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      children: [
                        TextSpan(text: 'Aqua', style: TextStyle(color: c.textPrimary)),
                        TextSpan(text: 'Control', style: TextStyle(color: c.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SMART WATER MANAGEMENT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 2.0),
                  ),
                  if (AppConfig.useMock) ...[
                    const SizedBox(height: 16),
                    _MockHint(c: c),
                  ],
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'MOBILE NUMBER',
                    hint: '98765 43210',
                    controller: _mobileCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text('+91', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        SizedBox(height: 20, child: VerticalDivider(color: c.cardBorder, width: 1)),
                      ],
                    ),
                    validator: (v) => (v == null || v.length < 10) ? 'Enter valid mobile' : null,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'PASSWORD',
                    controller: _passwordCtrl,
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text('Forgot Password?', style: TextStyle(color: c.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) => CustomButton(
                      label: 'Log In →',
                      isLoading: state is AuthLoading,
                      onTap: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(
                            LoginWithPassword(_mobileCtrl.text.trim(), _passwordCtrl.text),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: c.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider(color: c.divider)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: '📱  Continue with OTP',
                    variant: ButtonVariant.secondary,
                    onTap: () {
                      if (_mobileCtrl.text.length >= 10) {
                        context.read<AuthBloc>().add(SendLoginOtp(_mobileCtrl.text));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter mobile number first')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('New here? ', style: TextStyle(color: c.textSecondary)),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text('Create Account', style: TextStyle(color: c.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockHint extends StatelessWidget {
  final AppColorScheme c;
  const _MockHint({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, color: c.orange, size: 13),
              const SizedBox(width: 5),
              Text('MOCK MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.orange, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 6),
          _HintRow(label: 'Phone', value: AppConfig.mockPhone, c: c),
          const SizedBox(height: 2),
          _HintRow(label: 'OTP',   value: AppConfig.mockOtp,   c: c),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final String label, value;
  final AppColorScheme c;
  const _HintRow({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.orange, fontFamily: 'monospace')),
      ],
    );
  }
}
