import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class EditSocietySheet extends StatefulWidget {
  final String societyName;
  final String block;

  const EditSocietySheet({
    super.key,
    required this.societyName,
    required this.block,
  });

  static Future<void> show(
    BuildContext context, {
    required String societyName,
    required String block,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditSocietySheet(societyName: societyName, block: block),
    );
  }

  @override
  State<EditSocietySheet> createState() => _EditSocietySheetState();
}

class _EditSocietySheetState extends State<EditSocietySheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _blockCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.societyName);
    _blockCtrl = TextEditingController(text: widget.block);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _blockCtrl.dispose();
    super.dispose();
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
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
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
                child: Icon(Icons.apartment_rounded, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Society', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text('Update your society details', style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          CustomTextField(
            label: 'SOCIETY NAME',
            hint: 'e.g. Green Valley Apartments',
            controller: _nameCtrl,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'BLOCK / WING',
            hint: 'e.g. Block A',
            controller: _blockCtrl,
          ),
          const SizedBox(height: 28),

          CustomButton(
            label: 'Save Changes',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          CustomButton(
            label: 'Cancel',
            variant: ButtonVariant.secondary,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
