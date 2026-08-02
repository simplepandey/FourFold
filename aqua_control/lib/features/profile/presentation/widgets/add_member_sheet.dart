import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../data/repositories/society_repository.dart';

class AddMemberSheet extends StatefulWidget {
  final String societyId;

  const AddMemberSheet({super.key, required this.societyId});

  static Future<bool> show(BuildContext context, {required String societyId}) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMemberSheet(societyId: societyId),
    );
    return added == true;
  }

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _repo      = SocietyRepository();

  bool   _loading = false;
  String _error   = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = ''; });

    try {
      await _repo.addMember(
        societyId:   widget.societyId,
        phoneNumber: _phoneCtrl.text.trim(),
        name:        _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.appColors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: c.cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_add_rounded, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text('Invite someone to your society', style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  label: 'FULL NAME (OPTIONAL)',
                  hint: 'e.g. Jane Doe',
                  controller: _nameCtrl,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'PHONE NUMBER',
                  hint: '10-digit mobile number',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone number is required';
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits.length != 10) return 'Enter a valid 10-digit number';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Will be stored as +91XXXXXXXXXX',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),

                // Error message
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: c.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error, style: TextStyle(color: c.red, fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                CustomButton(
                  label: _loading ? 'Adding member…' : 'Add Member',
                  onTap: _loading ? null : _submit,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  label: 'Cancel',
                  variant: ButtonVariant.secondary,
                  onTap: _loading ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}