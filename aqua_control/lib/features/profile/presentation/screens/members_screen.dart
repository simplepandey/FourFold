import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/models/society_member_model.dart';
import '../../data/repositories/society_repository.dart';
import '../widgets/add_member_sheet.dart';

class MembersScreen extends StatefulWidget {
  final String societyId;
  const MembersScreen({super.key, required this.societyId});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _repo = SocietyRepository();
  List<SocietyMemberModel> _members = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final members = await _repo.getMembers(widget.societyId);
      if (mounted) setState(() { _members = members; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _changeRole(SocietyMemberModel member) async {
    final newRole = member.isAdmin ? 'member' : 'admin';
    final label  = member.isAdmin ? 'Remove admin rights' : 'Make admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: label,
        message: 'Change ${member.phoneNumber} to ${newRole == 'admin' ? 'Admin' : 'Member'}?',
        confirmLabel: label,
        confirmColor: newRole == 'admin' ? context.appColors.orange : context.appColors.primary,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final updated = await _repo.updateMemberRole(
        societyId: widget.societyId,
        memberId:  member.id,
        role:      newRole,
      );
      if (mounted) {
        setState(() {
          final idx = _members.indexWhere((m) => m.id == member.id);
          if (idx != -1) _members[idx] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: context.appColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deleteMember(SocietyMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Remove Member',
        message: 'Remove ${member.phoneNumber} from the society? This cannot be undone.',
        confirmLabel: 'Remove',
        confirmColor: context.appColors.red,
        destructive: true,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repo.deleteMember(societyId: widget.societyId, memberId: member.id);
      if (mounted) setState(() => _members.removeWhere((m) => m.id == member.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: context.appColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _addMember() async {
    final added = await AddMemberSheet.show(context, societyId: widget.societyId);
    if (added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Member added'),
        backgroundColor: context.appColors.green,
        behavior: SnackBarBehavior.floating,
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Society Members', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_rounded, color: c.primary),
            tooltip: 'Add member',
            onPressed: _addMember,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(c),
    );
  }

  Widget _buildBody(AppColorScheme c) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: c.red, size: 48),
              const SizedBox(height: 16),
              Text(_error, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              CustomButton(label: 'Retry', onTap: _load),
            ],
          ),
        ),
      );
    }

    if (_members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_outlined, color: c.textMuted, size: 64),
              const SizedBox(height: 16),
              Text('No members yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
              const SizedBox(height: 8),
              Text('Tap + to add the first member.', style: TextStyle(color: c.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final admins  = _members.where((m) => m.isAdmin).toList();
    final members = _members.where((m) => !m.isAdmin).toList();

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Summary chip row
          Row(
            children: [
              _CountChip(label: '${_members.length} total', color: c.primary),
              const SizedBox(width: 8),
              _CountChip(label: '${admins.length} admin${admins.length == 1 ? '' : 's'}', color: c.orange),
              const SizedBox(width: 8),
              _CountChip(label: '${members.length} member${members.length == 1 ? '' : 's'}', color: c.textMuted),
            ],
          ),
          const SizedBox(height: 20),

          if (admins.isNotEmpty) ...[
            _SectionLabel(label: 'ADMINS', color: c.textLabel),
            const SizedBox(height: 10),
            ...admins.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemberCard(
                member:       m,
                colors:       c,
                onChangeRole: () => _changeRole(m),
                onDelete:     () => _deleteMember(m),
              ),
            )),
            const SizedBox(height: 10),
          ],

          if (members.isNotEmpty) ...[
            _SectionLabel(label: 'MEMBERS', color: c.textLabel),
            const SizedBox(height: 10),
            ...members.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemberCard(
                member:       m,
                colors:       c,
                onChangeRole: () => _changeRole(m),
                onDelete:     () => _deleteMember(m),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// ─── Reusable sub-widgets ────────────────────────────────────────────────────

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CountChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) =>
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 1.2));
}

class _MemberCard extends StatelessWidget {
  final SocietyMemberModel member;
  final AppColorScheme colors;
  final VoidCallback onChangeRole;
  final VoidCallback onDelete;

  const _MemberCard({
    required this.member,
    required this.colors,
    required this.onChangeRole,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c       = colors;
    final roleColor = member.isAdmin ? c.orange : c.primary;
    final initials  = member.phoneNumber.substring(member.phoneNumber.length - 4);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(initials, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: roleColor)),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.phoneNumber, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        member.role.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleColor, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Joined ${_formatDate(member.joinedAt)}',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: member.isAdmin ? Icons.person_remove_rounded : Icons.admin_panel_settings_rounded,
                color: c.orange,
                tooltip: member.isAdmin ? 'Remove admin' : 'Make admin',
                onTap: onChangeRole,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.delete_outline_rounded,
                color: c.red,
                tooltip: 'Remove from society',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final bool destructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
      content: Text(message, style: TextStyle(fontSize: 14, color: c.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: c.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel, style: TextStyle(color: confirmColor, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}