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

enum _Step { mobile, otp, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _mobileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  _Step _step = _Step.mobile;

  String get _mobile => _mobileCtrl.text.trim();
  String get _otp => _otpCtrls.map((c) => c.text).join();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ForgotPasswordOtpSent) {
          setState(() => _step = _Step.otp);
        } else if (state is ForgotPasswordOtpVerified) {
          setState(() => _step = _Step.newPassword);
        } else if (state is AuthAuthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Password updated successfully'), backgroundColor: c.primary),
          );
          context.go('/home');
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: c.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          leading: GestureDetector(
            onTap: () {
              if (_step == _Step.mobile) {
                context.pop();
              } else if (_step == _Step.otp) {
                setState(() {
                  _step = _Step.mobile;
                  for (final ctrl in _otpCtrls) ctrl.clear();
                });
              } else {
                setState(() => _step = _Step.otp);
              }
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_back_ios_new, size: 16, color: c.textPrimary),
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: switch (_step) {
                _Step.mobile => _MobileStep(
                    key: const ValueKey('mobile'),
                    formKey: _mobileFormKey,
                    mobileCtrl: _mobileCtrl,
                    colors: c,
                    onSendOtp: () {
                      if (_mobileFormKey.currentState!.validate()) {
                        context.read<AuthBloc>().add(SendForgotPasswordOtp(_mobile));
                      }
                    },
                  ),
                _Step.otp => _OtpStep(
                    key: const ValueKey('otp'),
                    mobile: _mobile,
                    ctrls: _otpCtrls,
                    focusNodes: _otpFocus,
                    otp: _otp,
                    colors: c,
                    onVerify: () {
                      if (_otp.length == 6) {
                        context.read<AuthBloc>().add(VerifyForgotPasswordOtp(_mobile, _otp));
                      }
                    },
                    onResend: () => context.read<AuthBloc>().add(SendForgotPasswordOtp(_mobile)),
                  ),
                _Step.newPassword => _NewPasswordStep(
                    key: const ValueKey('new-password'),
                    formKey: _passwordFormKey,
                    newPasswordCtrl: _newPasswordCtrl,
                    confirmPasswordCtrl: _confirmPasswordCtrl,
                    colors: c,
                    onSubmit: () {
                      if (_passwordFormKey.currentState!.validate()) {
                        context.read<AuthBloc>().add(ResetPassword(_mobile, _newPasswordCtrl.text));
                      }
                    },
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step 1: mobile number ─────────────────────────────────────

class _MobileStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController mobileCtrl;
  final AppColorScheme colors;
  final VoidCallback onSendOtp;

  const _MobileStep({
    super.key,
    required this.formKey,
    required this.mobileCtrl,
    required this.colors,
    required this.onSendOtp,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('Forgot Password', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(
            "Enter your registered mobile number and we'll send you an OTP",
            style: TextStyle(fontSize: 14, color: c.textSecondary),
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
          const SizedBox(height: 32),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => CustomButton(
              label: 'Send OTP →',
              isLoading: state is AuthLoading,
              onTap: onSendOtp,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Step 2: OTP verification ───────────────────────────────────

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

// ─── Step 3: set new password ───────────────────────────────────

class _NewPasswordStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController newPasswordCtrl, confirmPasswordCtrl;
  final AppColorScheme colors;
  final VoidCallback onSubmit;

  const _NewPasswordStep({
    super.key,
    required this.formKey,
    required this.newPasswordCtrl,
    required this.confirmPasswordCtrl,
    required this.colors,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('Set New Password', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'OTP verified. Choose a new password for your account.',
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
          const SizedBox(height: 32),
          CustomTextField(
            label: 'NEW PASSWORD',
            controller: newPasswordCtrl,
            obscureText: true,
            validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
          ),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'CONFIRM PASSWORD',
            controller: confirmPasswordCtrl,
            obscureText: true,
            validator: (v) => (v != newPasswordCtrl.text) ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 32),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => CustomButton(
              label: 'Update Password →',
              isLoading: state is AuthLoading,
              onTap: onSubmit,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
