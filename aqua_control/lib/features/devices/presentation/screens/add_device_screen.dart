import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/device_repository.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  int _step = 0;
  bool _isLoading = false;
  String? _error;

  // Step 0 — product code
  final _productCodeCtrl = TextEditingController();

  // Step 1 — device configuration
  final _nameCtrl = TextEditingController();
  int _noOfPumps = 1;
  final _hpCtrl = TextEditingController();
  String _phase = '1-Phase';

  // Step 2 — location
  final _addressCtrl  = TextEditingController();
  final _wingCtrl     = TextEditingController();
  final _pincodeCtrl  = TextEditingController();
  final _districtCtrl = TextEditingController();

  @override
  void dispose() {
    _productCodeCtrl.dispose();
    _nameCtrl.dispose();
    _hpCtrl.dispose();
    _addressCtrl.dispose();
    _wingCtrl.dispose();
    _pincodeCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateProductCode() async {
    final code = _productCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a product code');
      return;
    }
    _productCodeCtrl.text = code; // normalize displayed text before moving to step 1
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = context.read<DeviceRepository>();
      await repo.validateProductCode(code);
      if (mounted) setState(() { _step = 1; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _advanceToLocation() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a name for this device');
      return;
    }
    final hp = double.tryParse(_hpCtrl.text.trim());
    if (hp == null || hp <= 0) {
      setState(() => _error = 'Please enter a valid HP (e.g. 1.5)');
      return;
    }
    setState(() { _step = 2; _error = null; });
  }

  Future<void> _submitRegistration() async {
    final address  = _addressCtrl.text.trim();
    final wing     = _wingCtrl.text.trim();
    final pincode  = _pincodeCtrl.text.trim();
    final district = _districtCtrl.text.trim();

    if (address.isEmpty || wing.isEmpty || pincode.isEmpty || district.isEmpty) {
      setState(() => _error = 'Please fill in all location fields');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String societyCode = '';
    String userId = '';
    String userName = '';
    if (authState is AuthAuthenticated) {
      societyCode = authState.user.societyCode;
      userId      = authState.user.id;
      userName    = authState.user.name;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = context.read<DeviceRepository>();
      await repo.registerModule(
        productCode: _productCodeCtrl.text.trim(),
        name:         _nameCtrl.text.trim(),
        societyCode:  societyCode,
        noOfPump:     _noOfPumps,
        phase:        _phase,
        hpOfPump:     double.parse(_hpCtrl.text.trim()),
        address:      address,
        wingBlock:    wing,
        pincode:      pincode,
        district:     district,
        createdBy:    userName.isNotEmpty ? userName : 'app',
        userId:       userId.isNotEmpty ? userId : null,
      );
      if (mounted) setState(() { _step = 3; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: c.textPrimary),
          ),
        ),
        title: Text('Add New Device', style: TextStyle(color: c.textPrimary)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _StepIndicator(currentStep: _step),
              const SizedBox(height: 32),
              Expanded(child: _stepContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContent() => switch (_step) {
        0 => _ScanStep(
            productCodeCtrl: _productCodeCtrl,
            isLoading: _isLoading,
            error: _error,
            onCameraOpen: () {},
            onNext: _validateProductCode,
          ),
        1 => _DetailsStep(
            productCode: _productCodeCtrl.text,
            nameCtrl: _nameCtrl,
            noOfPumps: _noOfPumps,
            hpCtrl: _hpCtrl,
            phase: _phase,
            isLoading: _isLoading,
            error: _error,
            onPumpsChanged: (v) => setState(() => _noOfPumps = v),
            onPhaseChanged: (v) => setState(() => _phase = v),
            onSubmit: _advanceToLocation,
            onBack: () => setState(() { _step = 0; _error = null; }),
          ),
        2 => _LocationStep(
            addressCtrl: _addressCtrl,
            wingCtrl: _wingCtrl,
            pincodeCtrl: _pincodeCtrl,
            districtCtrl: _districtCtrl,
            isLoading: _isLoading,
            error: _error,
            onSubmit: _submitRegistration,
            onBack: () => setState(() { _step = 1; _error = null; }),
          ),
        _ => _DoneStep(onDone: () => context.pop()),
      };
}

// ─── Step Indicator ───────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: List.generate(4, (i) {
        final done = i < currentStep;
        final active = i == currentStep;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: active ? c.primary : done ? c.green : c.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? c.primary : done ? c.green : c.cardBorder),
                ),
                alignment: Alignment.center,
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : c.textMuted)),
              ),
              if (i < 3)
                Expanded(child: Container(height: 2, color: done ? c.green : c.cardBorder)),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Step 0: Scan / Serial ────────────────────────────────────

class _ScanStep extends StatelessWidget {
  final TextEditingController productCodeCtrl;
  final bool isLoading;
  final String? error;
  final VoidCallback onCameraOpen;
  final VoidCallback onNext;

  const _ScanStep({
    required this.productCodeCtrl,
    required this.isLoading,
    required this.error,
    required this.onCameraOpen,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scan Device QR Code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 8),
          Text('Scan the QR code on your controller, or enter the product code manually.',
              style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 32),
          Container(
            height: 200,
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.cardBorder)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(border: Border.all(color: c.primary, width: 2), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Icon(Icons.qr_code_scanner, color: c.primary, size: 56)),
                ),
                const SizedBox(height: 12),
                CustomButton(label: '📷  Open Camera Scanner', height: 42, onTap: onCameraOpen),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: c.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ENTER MANUALLY', style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
              ),
              Expanded(child: Divider(color: c.divider)),
            ],
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'PRODUCT CODE',
            hint: 'e.g. FF00100',
            controller: productCodeCtrl,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              _UpperCaseFormatter(),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: error!),
          ],
          const SizedBox(height: 24),
          isLoading
              ? _LoadingButton(label: 'Validating…')
              : CustomButton(label: 'Next →', onTap: onNext),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Step 1: Device Configuration ──────────────────────────────

class _DetailsStep extends StatelessWidget {
  final String productCode;
  final TextEditingController nameCtrl;
  final int noOfPumps;
  final TextEditingController hpCtrl;
  final String phase;
  final bool isLoading;
  final String? error;
  final ValueChanged<int> onPumpsChanged;
  final ValueChanged<String> onPhaseChanged;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _DetailsStep({
    required this.productCode,
    required this.nameCtrl,
    required this.noOfPumps,
    required this.hpCtrl,
    required this.phase,
    required this.isLoading,
    required this.error,
    required this.onPumpsChanged,
    required this.onPhaseChanged,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device Configuration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.memory_outlined, size: 14, color: c.textMuted),
              const SizedBox(width: 6),
              Text('Product Code: $productCode', style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 28),

          // Device name
          CustomTextField(
            label: 'NAME',
            hint: 'e.g. Terrace Pump',
            controller: nameCtrl,
          ),
          const SizedBox(height: 20),

          // No. of pumps
          _DropdownField<int>(
            label: 'NO. OF PUMPS',
            value: noOfPumps,
            items: List.generate(10, (i) => i + 1),
            itemLabel: (v) => '$v pump${v > 1 ? 's' : ''}',
            onChanged: onPumpsChanged,
          ),
          const SizedBox(height: 20),

          // HP of pumps
          CustomTextField(
            label: 'HP OF PUMP',
            hint: 'e.g. 1.5',
            controller: hpCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),
          const SizedBox(height: 20),

          // Phase
          _DropdownField<String>(
            label: 'PHASE',
            value: phase,
            items: const ['1-Phase', '2-Phase', '3-Phase'],
            itemLabel: (v) => v,
            onChanged: onPhaseChanged,
          ),

          if (error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: error!),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: CustomButton(label: '← Back', variant: ButtonVariant.secondary, onTap: isLoading ? () {} : onBack)),
              const SizedBox(width: 12),
              Expanded(
                child: isLoading
                    ? _LoadingButton(label: 'Validating…')
                    : CustomButton(label: 'Next →', onTap: onSubmit),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Step 2: Location ─────────────────────────────────────────

class _LocationStep extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController wingCtrl;
  final TextEditingController pincodeCtrl;
  final TextEditingController districtCtrl;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _LocationStep({
    required this.addressCtrl,
    required this.wingCtrl,
    required this.pincodeCtrl,
    required this.districtCtrl,
    required this.isLoading,
    required this.error,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device Location', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text('Enter the installation address of the module.', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 28),

          CustomTextField(label: 'ADDRESS', hint: 'e.g. Plot 12, Near Water Tank', controller: addressCtrl),
          const SizedBox(height: 20),
          CustomTextField(label: 'WING / BLOCK', hint: 'e.g. A Wing', controller: wingCtrl),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'PINCODE',
            hint: 'e.g. 411001',
            controller: pincodeCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 20),
          CustomTextField(label: 'DISTRICT', hint: 'e.g. Pune', controller: districtCtrl),
          const SizedBox(height: 20),

          // Hardcoded state & country
          Row(
            children: [
              Expanded(child: _ReadOnlyChip(label: 'STATE', value: 'Maharashtra', colors: c)),
              const SizedBox(width: 12),
              Expanded(child: _ReadOnlyChip(label: 'COUNTRY', value: 'India', colors: c)),
            ],
          ),

          if (error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: error!),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: CustomButton(label: '← Back', variant: ButtonVariant.secondary, onTap: isLoading ? () {} : onBack)),
              const SizedBox(width: 12),
              Expanded(
                child: isLoading
                    ? const _LoadingButton(label: 'Registering…')
                    : CustomButton(label: 'Register Device', onTap: onSubmit),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ReadOnlyChip extends StatelessWidget {
  final String label;
  final String value;
  final dynamic colors;
  const _ReadOnlyChip({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.cardBorder),
          ),
          child: Text(value, style: TextStyle(fontSize: 15, color: c.textMuted)),
        ),
      ],
    );
  }
}

// ─── Step 3: Done ─────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  final VoidCallback onDone;
  const _DoneStep({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: c.green.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(Icons.check, color: c.green, size: 40),
        ),
        const SizedBox(height: 24),
        Text('Device Registered!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        Text('Your device has been successfully registered and is ready to use.',
            style: TextStyle(fontSize: 14, color: c.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 48),
        CustomButton(label: 'Done', onTap: onDone),
      ],
    );
  }
}

// ─── Shared Helpers ───────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textLabel, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: c.surface,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
            items: items
                .map((item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabel(item), style: TextStyle(color: c.textPrimary)),
                    ))
                .toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: c.red),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: c.red))),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) =>
      next.copyWith(text: next.text.toUpperCase(), selection: next.selection);
}

class _LoadingButton extends StatelessWidget {
  final String label;
  const _LoadingButton({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
