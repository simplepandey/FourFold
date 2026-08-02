import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
  final _formKey  = GlobalKey<FormState>();
  final _mobileCtrl   = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  bool _otpStep = false;

  String get _mobile => _mobileCtrl.text.trim();
  String get _otp    => _otpCtrls.map((c) => c.text).join();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is LoginOtpSent) {
          setState(() => _otpStep = true);
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: c.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _otpStep
            ? AppBar(
                backgroundColor: c.background,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => setState(() {
                    _otpStep = false;
                    for (final ctrl in _otpCtrls) ctrl.clear();
                  }),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.arrow_back_ios_new, size: 16, color: c.textPrimary),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _otpStep
                  ? _OtpStep(
                      key: const ValueKey('otp'),
                      mobile: _mobile,
                      ctrls: _otpCtrls,
                      focusNodes: _otpFocus,
                      otp: _otp,
                      colors: c,
                      onVerify: () {
                        if (_otp.length == 6) {
                          context.read<AuthBloc>().add(VerifyLoginOtp(_mobile, _otp));
                        }
                      },
                      onResend: () => context.read<AuthBloc>().add(SendLoginOtp(_mobile)),
                    )
                  : _LoginForm(
                      key: const ValueKey('login'),
                      formKey: _formKey,
                      mobileCtrl: _mobileCtrl,
                      passwordCtrl: _passwordCtrl,
                      colors: c,
                      onLogin: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(
                            LoginWithPassword(_mobile, _passwordCtrl.text),
                          );
                        }
                      },
                      onSendOtp: () {
                        if (_mobile.length >= 10) {
                          context.read<AuthBloc>().add(SendLoginOtp(_mobile));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enter mobile number first')),
                          );
                        }
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Login form (phone + password) ───────────────────────────

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController mobileCtrl, passwordCtrl;
  final AppColorScheme colors;
  final VoidCallback onLogin, onSendOtp;

  const _LoginForm({
    super.key,
    required this.formKey,
    required this.mobileCtrl,
    required this.passwordCtrl,
    required this.colors,
    required this.onLogin,
    required this.onSendOtp,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 56),
          Container(
            width: 80, height: 80,
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
                TextSpan(text: 'Aqua',    style: TextStyle(color: c.textPrimary)),
                TextSpan(text: 'Control', style: TextStyle(color: c.primary)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SMART WATER MANAGEMENT',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 2.0),
          ),
          const SizedBox(height: 32),
          CustomTextField(
            label: 'MOBILE NUMBER',
            hint: '98765 43210',
            controller: mobileCtrl,
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
            controller: passwordCtrl,
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
              onTap: onLogin,
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
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => CustomButton(
              label: '📱  Continue with OTP',
              variant: ButtonVariant.secondary,
              isLoading: state is AuthLoading,
              onTap: onSendOtp,
            ),
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
    );
  }
}

// ─── OTP verification step ────────────────────────────────────

class _OtpStep extends StatelessWidget {
  final String mobile;
  final String otp;
  final List<TextEditingController> ctrls;
  final List<FocusNode> focusNodes;
  final AppColorScheme colors;
  final VoidCallback onVerify, onResend;

  const _OtpStep({
    super.key,
    required this.mobile,
    required this.otp,
    required this.ctrls,
    required this.focusNodes,
    required this.colors,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text('Verify OTP', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 6),
        Text(
          'Enter the 6-digit code sent to +91 $mobile',
          style: TextStyle(fontSize: 14, color: c.textSecondary),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => SizedBox(
            width: 46, height: 54,
            child: TextFormField(
              controller: ctrls[i],
              focusNode: focusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary, width: 2)),
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                if (v.isNotEmpty && i < 5) FocusScope.of(context).requestFocus(focusNodes[i + 1]);
                else if (v.isEmpty && i > 0) FocusScope.of(context).requestFocus(focusNodes[i - 1]);
              },
            ),
          )),
        ),
        const SizedBox(height: 36),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => CustomButton(
            label: 'Verify OTP →',
            isLoading: state is AuthLoading,
            onTap: onVerify,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: onResend,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: "Didn't receive it? ", style: TextStyle(color: c.textSecondary)),
              TextSpan(text: 'Resend OTP', style: TextStyle(color: c.primary, fontWeight: FontWeight.w600)),
            ])),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
