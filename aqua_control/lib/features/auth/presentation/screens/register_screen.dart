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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  final _mobileCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  final _detailsFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _societyCtrl = TextEditingController();
  final _blockCtrl = TextEditingController();
  final _membersCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String get _mobile => _mobileCtrl.text.trim();
  String get _otp => _otpCtrls.map((c) => c.text).join();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _nameCtrl.dispose();
    _societyCtrl.dispose();
    _blockCtrl.dispose();
    _membersCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is RegistrationOtpSent)     setState(() => _step = 1);
        else if (state is RegistrationOtpVerified) setState(() => _step = 2);
        else if (state is AuthAuthenticated)  context.go('/home');
        else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: c.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          leading: GestureDetector(
            onTap: () => _step > 0 ? setState(() => _step -= 1) : context.pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_back_ios_new, size: 16, color: c.textPrimary),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ProgressBar(step: _step),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: switch (_step) {
                      0 => _MobileStep(
                          key: const ValueKey(0),
                          ctrl: _mobileCtrl,
                          onNext: () {
                            if (_mobile.length >= 10) {
                              context.read<AuthBloc>().add(SendRegistrationOtp(_mobile));
                            }
                          },
                        ),
                      1 => _OtpStep(
                          key: const ValueKey(1),
                          mobile: _mobile,
                          ctrls: _otpCtrls,
                          focusNodes: _otpFocus,
                          onVerify: () {
                            if (_otp.length == 6) {
                              context.read<AuthBloc>().add(VerifyRegistrationOtp(_mobile, _otp));
                            }
                          },
                          onResend: () => context.read<AuthBloc>().add(SendRegistrationOtp(_mobile)),
                        ),
                      _ => _DetailsStep(
                          key: const ValueKey(2),
                          formKey: _detailsFormKey,
                          nameCtrl: _nameCtrl,
                          societyCtrl: _societyCtrl,
                          blockCtrl: _blockCtrl,
                          membersCtrl: _membersCtrl,
                          passwordCtrl: _passwordCtrl,
                          confirmCtrl: _confirmCtrl,
                          onSubmit: () {
                            if (_detailsFormKey.currentState!.validate()) {
                              context.read<AuthBloc>().add(CompleteRegistration(
                                    mobile: _mobile,
                                    name: _nameCtrl.text.trim(),
                                    societyName: _societyCtrl.text.trim(),
                                    block: _blockCtrl.text.trim(),
                                    totalMembers: int.tryParse(_membersCtrl.text) ?? 1,
                                    password: _passwordCtrl.text,
                                  ));
                            }
                          },
                        ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  const _ProgressBar({required this.step});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final labels = ['Mobile', 'Verify OTP', 'Your Details'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < step;
          final active = i == step;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: done ? c.green : active ? c.primary : c.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: done ? c.green : active ? c.primary : c.cardBorder),
                      ),
                      alignment: Alignment.center,
                      child: done
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : c.textMuted)),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? c.primary : c.textMuted, letterSpacing: 0.3)),
                  ],
                ),
                if (i < 2)
                  Expanded(
                    child: Container(height: 2, margin: const EdgeInsets.only(bottom: 18), color: done ? c.green : c.cardBorder),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _MobileStep extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onNext;
  const _MobileStep({super.key, required this.ctrl, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create Account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 6),
        Text('Enter your mobile number to get started.', style: TextStyle(fontSize: 14, color: c.textSecondary)),
        const SizedBox(height: 24),
        CustomTextField(
          label: 'MOBILE NUMBER',
          hint: '98765 43210',
          controller: ctrl,
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
          validator: (v) => (v == null || v.length < 10) ? 'Enter valid 10-digit number' : null,
        ),
        const SizedBox(height: 32),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => CustomButton(label: 'Send OTP →', isLoading: state is AuthLoading, onTap: onNext),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  final String mobile;
  final List<TextEditingController> ctrls;
  final List<FocusNode> focusNodes;
  final VoidCallback onVerify, onResend;
  const _OtpStep({super.key, required this.mobile, required this.ctrls, required this.focusNodes, required this.onVerify, required this.onResend});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verify OTP', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 6),
        Text('Enter the 6-digit code sent to +91 $mobile', style: TextStyle(fontSize: 14, color: c.textSecondary)),
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
        const SizedBox(height: 32),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => CustomButton(label: 'Verify OTP →', isLoading: state is AuthLoading, onTap: onVerify),
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
      ],
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, societyCtrl, blockCtrl, membersCtrl, passwordCtrl, confirmCtrl;
  final VoidCallback onSubmit;

  const _DetailsStep({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.societyCtrl,
    required this.blockCtrl,
    required this.membersCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Complete Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text('Fill in your details to finish registration.', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 28),
          CustomTextField(label: 'FULL NAME *',    hint: 'e.g. Navin Bind',            controller: nameCtrl,    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
          const SizedBox(height: 18),
          CustomTextField(label: 'SOCIETY NAME *', hint: 'e.g. Green Valley Society',  controller: societyCtrl, validator: (v) => (v == null || v.trim().isEmpty) ? 'Society name is required' : null),
          const SizedBox(height: 18),
          CustomTextField(label: 'BLOCK / WING *', hint: 'e.g. Block 4 or Wing A',     controller: blockCtrl,   validator: (v) => (v == null || v.trim().isEmpty) ? 'Block is required' : null),
          const SizedBox(height: 18),
          CustomTextField(
            label: 'TOTAL MEMBERS *', hint: 'e.g. 24',
            controller: membersCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if ((int.tryParse(v) ?? 0) < 1) return 'Must be at least 1';
              return null;
            },
          ),
          const SizedBox(height: 18),
          CustomTextField(
            label: 'PASSWORD *', controller: passwordCtrl, obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 18),
          CustomTextField(
            label: 'CONFIRM PASSWORD *', controller: confirmCtrl, obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm password';
              if (v != passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 32),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => CustomButton(label: 'Create Account →', isLoading: state is AuthLoading, onTap: onSubmit),
          ),
        ],
      ),
    );
  }
}
