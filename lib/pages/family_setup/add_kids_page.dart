import 'dart:math' as math;
import 'package:chorezilla/components/inputs.dart';
import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/components/premium_upgrade_sheet.dart';
import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/cosmetics.dart';

class AddKidsPage extends StatefulWidget {
  const AddKidsPage({super.key});

  @override
  State<AddKidsPage> createState() => _AddKidsPageState();
}

class _AddKidsPageState extends State<AddKidsPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _nameNode = FocusNode();
  int? _birthYear;
  int? _birthMonthNum;
  DateTime? get _birthMonth => (_birthYear != null && _birthMonthNum != null)
      ? DateTime(_birthYear!, _birthMonthNum!)
      : null;
  String? _avatarKey;
  bool _allowBonusChores = true;

  bool _busy = false;
  String? _error;
  String? _editingMemberId;

  final pinController = TextEditingController();
  final pinConfirmController = TextEditingController();

  final ChorezillaRepo _repo = ChorezillaRepo(
    firebaseDB: FirebaseFirestore.instance,
  );

  @override
  void dispose() {
    _name.dispose();
    _nameNode.dispose();
    pinController.dispose();
    pinConfirmController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) =>
          _AvatarPickerSheet(initial: _avatarKey),
    );
    if (!mounted) return;
    if (selected != null) setState(() => _avatarKey = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final app = context.read<AppState>();
    final familyId = app.family?.id;
    if (familyId == null || familyId.isEmpty) {
      setState(() => _error = 'No family selected/loaded yet.');
      return;
    }

    if (_editingMemberId == null) {
      final kidCount =
          app.members.where((m) => m.role == FamilyRole.child).length;
      if (!SubscriptionService.canAddKid(app.family, kidCount)) {
        if (!mounted) return;
        await showPremiumUpgradeSheet(context, reason: UpgradeReason.addKid);
        return;
      }
    }

    setState(() { _busy = true; _error = null; });

    try {
      if (_editingMemberId == null) {
        final newId = await _repo.addChild(
          familyId,
          displayName: _name.text.trim(),
          avatarKey: (_avatarKey?.trim().isEmpty ?? true) ? null : _avatarKey,
          pinHash: null,
        );
        final bm = _birthMonth;
        final patch = <String, dynamic>{
          if (bm != null) 'birthMonth': Timestamp.fromDate(bm),
          'allowBonusChores': _allowBonusChores,
        };
        if (patch.isNotEmpty) await _repo.updateMember(familyId, newId, patch);
        _clearFormAndRefocus();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Kid added')));
        }
      } else {
        final memberId = _editingMemberId!;
        final patch = <String, dynamic>{
          'displayName': _name.text.trim(),
          if (_avatarKey != null) 'avatarKey': _avatarKey,
          if (_birthMonth != null) 'birthMonth': Timestamp.fromDate(_birthMonth!),
          'allowBonusChores': _allowBonusChores,
        };
        await _repo.updateMember(familyId, memberId, patch);
        _clearFormAndRefocus();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Kid updated')));
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeKidFromFamily(Member m) async {
    final app = context.read<AppState>();
    final familyId = app.family?.id;
    if (familyId == null || familyId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${m.displayName}?'),
        content: const Text('This will remove the kid from your family. Their chore history will be kept but they will no longer appear on your dashboard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _busy = true; _error = null; });
    try {
      await app.removeMember(m.id);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startEdit(Member m) {
    setState(() {
      _editingMemberId = m.id;
      _name.text = m.displayName;
      _avatarKey = (m.avatarKey != null && m.avatarKey!.trim().isNotEmpty)
          ? m.avatarKey
          : null;
      _birthYear = m.birthMonth?.year;
      _birthMonthNum = m.birthMonth?.month;
      _allowBonusChores = m.allowBonusChores;
    });
    _nameNode.requestFocus();
  }

  void _cancelEdit() => setState(() {
    _editingMemberId = null;
    _error = null;
    _busy = false;
    _name.clear();
    _birthYear = null;
    _birthMonthNum = null;
    _avatarKey = null;
    _allowBonusChores = true;
    _nameNode.requestFocus();
  });

  void _clearFormAndRefocus() {
    _editingMemberId = null;
    _name.clear();
    _birthYear = null;
    _birthMonthNum = null;
    _avatarKey = null;
    _allowBonusChores = true;
    FocusScope.of(context).requestFocus(_nameNode);
  }

  Future<void> _showPinDialog(Member m) async {
    final app = context.read<AppState>();
    final hasExistingPin = (m.pinHash != null && m.pinHash!.trim().isNotEmpty);

    bool pinEnabled = hasExistingPin;
    String? error;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text('PIN for ${m.displayName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: pinEnabled,
                      onChanged: (value) {
                        setDialogState(() {
                          pinEnabled = value;
                          if (!value) {
                            pinController.clear();
                            pinConfirmController.clear();
                            error = null;
                          }
                        });
                      },
                      title: const Text('Require a PIN'),
                      subtitle: Text(
                        "When enabled, a 4-digit PIN is required to open this kid's dashboard. Parents can always use the parent PIN.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (pinEnabled) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: themedInput(ctx, '4-digit PIN'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pinConfirmController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: themedInput(ctx, 'Confirm PIN'),
                      ),
                      if (hasExistingPin)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Leave both fields blank to keep the existing PIN.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: TextStyle(color: cs.error)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!pinEnabled) {
                      if (hasExistingPin) {
                        await app.updateMemberPin(memberId: m.id, pin: null);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                      return;
                    }

                    final newPin = pinController.text.trim();
                    final confirmPin = pinConfirmController.text.trim();

                    if (newPin.isEmpty && hasExistingPin) {
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                      return;
                    }
                    if (newPin.isEmpty && !hasExistingPin) {
                      setDialogState(() => error =
                          'Enter a 4-digit PIN or turn PIN off to continue.');
                      return;
                    }
                    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
                      setDialogState(
                          () => error = 'PIN must be exactly 4 digits.');
                      return;
                    }
                    if (newPin != confirmPin) {
                      setDialogState(() => error = 'PINs do not match.');
                      return;
                    }

                    await app.updateMemberPin(memberId: m.id, pin: newPin);
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    pinController.clear();
    pinConfirmController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final kids = app.members
        .where((m) => m.role == FamilyRole.child && m.active)
        .toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final isEditing = _editingMemberId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids'),
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
        actions: [
          if (isEditing)
            TextButton.icon(
              onPressed: _busy ? null : _cancelEdit,
              icon: const Icon(Icons.clear, color: Colors.white),
              label: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Add / edit form ──────────────────────────────────────────
              _FormCard(
                formKey: _formKey,
                nameController: _name,
                nameFocusNode: _nameNode,
                avatarKey: _avatarKey,
                birthYear: _birthYear,
                birthMonthNum: _birthMonthNum,
                allowBonusChores: _allowBonusChores,
                busy: _busy,
                error: _error,
                isEditing: isEditing,
                onPickAvatar: _pickAvatar,
                onBirthYearChanged: (v) => setState(() => _birthYear = v),
                onBirthMonthChanged: (v) => setState(() => _birthMonthNum = v),
                onAllowBonusChoresChanged: (v) =>
                    setState(() => _allowBonusChores = v),
                onSave: _save,
                onNameChanged: () => setState(() {}),
              ),

              const SizedBox(height: 28),

              // ── Section header ───────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your Kids',
                    style: ts.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (kids.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${kids.length}',
                        style: ts.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (kids.isEmpty)
                _EmptyKidsState(cs: cs, ts: ts)
              else
                ...kids.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _KidCard(
                        member: m,
                        isBeingEdited: _editingMemberId == m.id,
                        busy: _busy,
                        onEdit: () => _startEdit(m),
                        onRemove: () => _removeKidFromFamily(m),
                        onPin: () => _showPinDialog(m),
                      ),
                    )),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Form card ────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.nameController,
    required this.nameFocusNode,
    required this.avatarKey,
    required this.birthYear,
    required this.birthMonthNum,
    required this.allowBonusChores,
    required this.busy,
    required this.error,
    required this.isEditing,
    required this.onPickAvatar,
    required this.onBirthYearChanged,
    required this.onBirthMonthChanged,
    required this.onAllowBonusChoresChanged,
    required this.onSave,
    required this.onNameChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final String? avatarKey;
  final int? birthYear;
  final int? birthMonthNum;
  final bool allowBonusChores;
  final bool busy;
  final String? error;
  final bool isEditing;
  final VoidCallback onPickAvatar;
  final ValueChanged<int?> onBirthYearChanged;
  final ValueChanged<int?> onBirthMonthChanged;
  final ValueChanged<bool> onAllowBonusChoresChanged;
  final VoidCallback onSave;
  final VoidCallback onNameChanged;

  String _initial(String name) {
    final n = name.trim();
    return n.isEmpty ? '?' : n.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final isImageAvatar = avatarKey?.startsWith('avatar_') ?? false;

    return Card(
      elevation: 2,
      shadowColor: cs.shadow.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.secondary,
                  cs.secondary.withValues(alpha: 0.75),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit Kid' : 'Add a Kid',
                  style: ts.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar preview + name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: busy ? null : onPickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.tertiaryContainer,
                                border: Border.all(
                                  color: cs.tertiary.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.shadow.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: isImageAvatar
                                  ? Image.asset(
                                      CosmeticCatalog.byId(avatarKey!)
                                          .assetKey,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Text(
                                        (avatarKey == null ||
                                                avatarKey!.trim().isEmpty)
                                            ? _initial(nameController.text)
                                            : avatarKey!,
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.primary,
                                  border: Border.all(
                                      color: cs.surface, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: nameController,
                          focusNode: nameFocusNode,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => onNameChanged(),
                          decoration:
                              themedInput(context, 'Name', hint: 'e.g., Sam'),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'Please enter a name';
                            if (t.length > 30) {
                              return 'Keep it under 30 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Birthday + avatar row (responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 480;
                      final currentYear = DateTime.now().year;
                      const monthNames = [
                        'January', 'February', 'March', 'April',
                        'May', 'June', 'July', 'August',
                        'September', 'October', 'November', 'December',
                      ];

                      final birthdayField = Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: birthMonthNum,
                              isExpanded: true,
                              decoration: themedInput(context, 'Month'),
                              items: List.generate(12, (i) => i + 1)
                                  .map((m) => DropdownMenuItem<int>(
                                        value: m,
                                        child: Text(monthNames[m - 1]),
                                      ))
                                  .toList(),
                              onChanged: busy ? null : onBirthMonthChanged,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: birthYear,
                              isExpanded: true,
                              decoration: themedInput(context, 'Year'),
                              items: List.generate(
                                      21, (i) => currentYear - i)
                                  .map((y) => DropdownMenuItem<int>(
                                        value: y,
                                        child: Text(y.toString()),
                                      ))
                                  .toList(),
                              onChanged: busy ? null : onBirthYearChanged,
                            ),
                          ),
                        ],
                      );

                      final avatarField = InkWell(
                        onTap: busy ? null : onPickAvatar,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: themedInput(context, 'Avatar'),
                          child: Row(
                            children: [
                              if (avatarKey?.startsWith('avatar_') == true)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    CosmeticCatalog.byId(avatarKey!).assetKey,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Icon(Icons.face_rounded,
                                    size: 28, color: cs.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  avatarKey?.startsWith('avatar_') == true
                                      ? CosmeticCatalog.byId(avatarKey!).name
                                      : 'Choose avatar',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: busy ? null : onPickAvatar,
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Pick'),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            birthdayField,
                            const SizedBox(height: 12),
                            avatarField,
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(child: birthdayField),
                            const SizedBox(width: 12),
                            Expanded(child: avatarField),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: allowBonusChores,
                    onChanged:
                        busy ? null : onAllowBonusChoresChanged,
                    title: const Text('Show bonus chores'),
                    subtitle: const Text(
                      'Lets this kid see optional extra chores for extra coins and XP.',
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onSave,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isEditing ? Icons.save : Icons.add),
                      label:
                          Text(isEditing ? 'Save changes' : 'Add kid'),
                    ),
                  ),

                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kid card ─────────────────────────────────────────────────────────────────

class _KidCard extends StatelessWidget {
  const _KidCard({
    required this.member,
    required this.isBeingEdited,
    required this.busy,
    required this.onEdit,
    required this.onRemove,
    required this.onPin,
  });

  final Member member;
  final bool isBeingEdited;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final hasPin =
        (member.pinHash != null && member.pinHash!.trim().isNotEmpty);
    final isImageAvatar = member.avatarKey?.startsWith('avatar_') ?? false;
    final levelInfo = levelInfoForXp(member.xp);
    final hasStreak = member.effectiveStreak > 1;

    final title = member.equippedTitleId != null &&
            member.equippedTitleId!.isNotEmpty &&
            member.equippedTitleId != 'title_none'
        ? CosmeticCatalog.byId(member.equippedTitleId!).name
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(
          color: isBeingEdited ? cs.primary : cs.outlineVariant,
          width: isBeingEdited ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isBeingEdited
                ? cs.primary.withValues(alpha: 0.12)
                : cs.shadow.withValues(alpha: 0.06),
            blurRadius: isBeingEdited ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + name/title/level + actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.tertiaryContainer,
                    border: Border.all(
                      color: cs.tertiary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isImageAvatar
                      ? Image.asset(
                          CosmeticCatalog.byId(member.avatarKey!).assetKey,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            (member.avatarKey == null ||
                                    member.avatarKey!.trim().isEmpty)
                                ? _initial(member.displayName)
                                : member.avatarKey!,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Name, title, level badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.displayName,
                              style: ts.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _LevelBadge(level: member.level, cs: cs, ts: ts),
                        ],
                      ),
                      if (title != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: ts.labelSmall?.copyWith(
                            color: cs.primary,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionIconButton(
                      tooltip: hasPin ? 'Edit PIN' : 'Set PIN',
                      onPressed: busy ? null : onPin,
                      icon: hasPin
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      color: hasPin ? cs.primary : cs.onSurfaceVariant,
                    ),
                    _ActionIconButton(
                      tooltip: 'Edit',
                      onPressed: busy ? null : onEdit,
                      icon: Icons.edit_outlined,
                      color: cs.primary,
                    ),
                    _ActionIconButton(
                      tooltip: 'Remove',
                      onPressed: busy ? null : onRemove,
                      icon: Icons.person_remove_outlined,
                      color: cs.error,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // XP progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'XP',
                      style: ts.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${levelInfo.xpIntoLevel} / ${levelInfo.xpNeededThisLevel}',
                      style: ts.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: levelInfo.progress,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Stats row: coins, streak, bonus chores
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatChip(
                  icon: '🪙',
                  label: '${member.coins}',
                  cs: cs,
                  ts: ts,
                ),
                if (hasStreak)
                  _StatChip(
                    icon: '🔥',
                    label: '${member.effectiveStreak} day streak',
                    cs: cs,
                    ts: ts,
                    highlighted: true,
                  ),
                if (member.allowBonusChores)
                  _StatChip(
                    icon: '⭐',
                    label: 'Bonus chores on',
                    cs: cs,
                    ts: ts,
                  ),
                if (member.badges.isNotEmpty)
                  _StatChip(
                    icon: '🏅',
                    label: '${member.badges.length} badges',
                    cs: cs,
                    ts: ts,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String name) {
    final n = name.trim();
    return n.isEmpty ? '?' : n.characters.first.toUpperCase();
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.level,
    required this.cs,
    required this.ts,
  });

  final int level;
  final ColorScheme cs;
  final TextTheme ts;

  @override
  Widget build(BuildContext context) {
    final isHighLevel = level >= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: isHighLevel
            ? LinearGradient(
                colors: [
                  const Color(0xFFFFB300),
                  const Color(0xFFFF6F00),
                ],
              )
            : null,
        color: isHighLevel ? null : cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Lv $level',
        style: ts.labelSmall?.copyWith(
          color: isHighLevel ? Colors.white : cs.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.cs,
    required this.ts,
    this.highlighted = false,
  });

  final String icon;
  final String label;
  final ColorScheme cs;
  final TextTheme ts;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? cs.errorContainer.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: ts.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: highlighted ? cs.error : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.color,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: onPressed == null ? color.withValues(alpha: 0.4) : color, size: 20),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyKidsState extends StatelessWidget {
  const _EmptyKidsState({required this.cs, required this.ts});

  final ColorScheme cs;
  final TextTheme ts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/mascot/grey-scale-mascot.png',
            height: 72,
            opacity: const AlwaysStoppedAnimation(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No kids yet',
            style: ts.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first kid above to get started.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Avatar picker sheet ──────────────────────────────────────────────────────

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({this.initial});

  final String? initial;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late String _selected;

  static final _defaultImageIds = CosmeticCatalog.avatars()
      .where((a) => a.isDefault)
      .map((a) => a.id)
      .toList();

  @override
  void initState() {
    super.initState();
    final validInitial = widget.initial?.startsWith('avatar_') == true
        ? widget.initial!
        : null;
    _selected = validInitial ??
        (_defaultImageIds.isNotEmpty ? _defaultImageIds.first : '');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final isImageSelected = _selected.startsWith('avatar_');
    final previewChild = isImageSelected
        ? ClipOval(
            child: Image.asset(
              CosmeticCatalog.byId(_selected).assetKey,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          )
        : Text(_selected, style: const TextStyle(fontSize: 22));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: SizedBox(
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.tertiaryContainer,
                  child: previewChild,
                ),
                const SizedBox(width: 12),
                Text('Pick an avatar', style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = math.max(
                    4,
                    math.min(8, (constraints.maxWidth / 64).floor()),
                  );
                  return GridView.count(
                    crossAxisCount: count,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final id in _defaultImageIds)
                        _AvatarTile(
                          avatarKey: id,
                          selected: id == _selected,
                          onTap: () => setState(() => _selected = id),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  icon: const Icon(Icons.check),
                  label: const Text('Use avatar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.avatarKey,
    required this.selected,
    required this.onTap,
  });

  final String avatarKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isImage = avatarKey.startsWith('avatar_');
    final child = isImage
        ? Image.asset(
            CosmeticCatalog.byId(avatarKey).assetKey,
            fit: BoxFit.cover,
          )
        : Text(avatarKey, style: const TextStyle(fontSize: 24));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? cs.primaryContainer : null,
          border: Border.all(
            width: selected ? 2 : 1,
            color: selected ? cs.primary : cs.outlineVariant,
          ),
        ),
        alignment: Alignment.center,
        child: isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: child,
              )
            : child,
      ),
    );
  }
}

