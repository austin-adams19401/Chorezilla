import 'dart:math' as math;
import 'package:chorezilla/components/inputs.dart';
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

class AddKidsPage extends StatefulWidget {
  const AddKidsPage({super.key});

  @override
  State<AddKidsPage> createState() => _AddKidsPageState();
}

class _AddKidsPageState extends State<AddKidsPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _nameNode = FocusNode();
  int? _age;
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
          _AvatarPickerSheet(avatars: _defaultAvatars, initial: _avatarKey),
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
        final patch = <String, dynamic>{
          if (_age != null) 'age': _age,
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
          if (_age != null) 'age': _age,
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
      _age = m.age;
      _allowBonusChores = m.allowBonusChores;
    });
    _nameNode.requestFocus();
  }

  void _cancelEdit() => setState(() {
    _editingMemberId = null;
    _error = null;
    _busy = false;
    _name.clear();
    _age = null;
    _avatarKey = null;
    _allowBonusChores = true;
    _nameNode.requestFocus();
  });

  void _clearFormAndRefocus() {
    _editingMemberId = null;
    _name.clear();
    _age = null;
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
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit kid' : 'Add a kid',
                          style: ts.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Avatar preview + name
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _busy ? null : _pickAvatar,
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: cs.tertiaryContainer,
                                child: Text(
                                  (_avatarKey == null ||
                                          _avatarKey!.trim().isEmpty)
                                      ? _initial(_name.text)
                                      : _avatarKey!,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _name,
                                focusNode: _nameNode,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: themedInput(context, 'Name',
                                    hint: 'e.g., Sam'),
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
                        const SizedBox(height: 12),

                        // Age + avatar row (responsive)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 480;

                            final ageField = DropdownButtonFormField<int>(
                              initialValue: _age,
                              isExpanded: true,
                              decoration: themedInput(context, 'Age (optional)'),
                              items: List.generate(42, (i) => i + 3)
                                  .map((a) => DropdownMenuItem<int>(
                                        value: a,
                                        child: Text(a.toString()),
                                      ))
                                  .toList(),
                              onChanged:
                                  _busy ? null : (v) => setState(() => _age = v),
                            );

                            final avatarField = InputDecorator(
                              decoration: themedInput(context, 'Avatar'),
                              child: Row(
                                children: [
                                  Text(
                                    (_avatarKey == null ||
                                            _avatarKey!.trim().isEmpty)
                                        ? '🙂'
                                        : _avatarKey!,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Choose emoji',
                                      style: ts.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: _busy ? null : _pickAvatar,
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Pick'),
                                  ),
                                ],
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  ageField,
                                  const SizedBox(height: 12),
                                  avatarField,
                                ],
                              );
                            } else {
                              return Row(
                                children: [
                                  Expanded(child: ageField),
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
                          value: _allowBonusChores,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _allowBonusChores = v),
                          title: const Text('Show bonus chores'),
                          subtitle: const Text(
                            'Lets this kid see optional extra chores for extra coins and XP.',
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: const StadiumBorder(),
                            ),
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(isEditing ? Icons.save : Icons.add),
                            label: Text(isEditing ? 'Save changes' : 'Add kid'),
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: TextStyle(color: cs.error)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Current kids list ────────────────────────────────────────
              Text(
                'Current kids',
                style: ts.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              if (kids.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No kids yet — add one above.',
                    style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),

              ...kids.map((m) {
                final hasPin =
                    (m.pinHash != null && m.pinHash!.trim().isNotEmpty);
                final isBeingEdited = _editingMemberId == m.id;

                return Card(
                  shape: isBeingEdited
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: cs.primary, width: 2),
                        )
                      : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.tertiaryContainer,
                      child: Text(
                        (m.avatarKey == null || m.avatarKey!.trim().isEmpty)
                            ? _initial(m.displayName)
                            : m.avatarKey!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(m.displayName),
                    subtitle: Text(
                      'Level ${m.level} • ${m.xp} XP • ${m.coins} coins',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: hasPin ? 'Edit PIN' : 'Set PIN',
                          onPressed: _busy ? null : () => _showPinDialog(m),
                          icon: Icon(
                            hasPin
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            color: hasPin ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: _busy ? null : () => _startEdit(m),
                          icon: Icon(Icons.edit_outlined, color: cs.primary),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: _busy ? null : () => _removeKidFromFamily(m),
                          icon: Icon(Icons.person_remove_outlined,
                              color: cs.error),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(String name) {
    final n = name.trim();
    return n.isEmpty ? '?' : n.characters.first.toUpperCase();
  }
}

// ── Avatar picker sheet ──────────────────────────────────────────────────────

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({required this.avatars, this.initial});

  final List<String> avatars;
  final String? initial;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ??
        (widget.avatars.isNotEmpty ? widget.avatars.first : '🙂');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

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
                  child: Text(_selected, style: const TextStyle(fontSize: 22)),
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
                      for (final a in widget.avatars)
                        _EmojiTile(
                          emoji: a,
                          selected: a == _selected,
                          onTap: () => setState(() => _selected = a),
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

class _EmojiTile extends StatelessWidget {
  const _EmojiTile({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

const _defaultAvatars = [
  '🦖', '🦄', '🐱', '🐶', '🐵', '🐼', '🦊', '🐯',
  '🐸', '🐨', '🐰', '🐮', '🐹', '🐻', '🐷', '🐭',
  '🦁', '🐔', '🐥', '🦉', '🦋', '🐞', '🐙', '🐳',
  '🚀', '⚽', '🎮', '🎲', '🎸', '🎯', '🌈', '🍕',
  '🍩', '🍪', '🍎', '🧩',
];
