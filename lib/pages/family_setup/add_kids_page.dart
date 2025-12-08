import 'dart:math' as math;
import 'package:chorezilla/data/chorezilla_repo.dart';
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

  // Inputs
  final _name = TextEditingController();
  final _nameNode = FocusNode();
  int? _age; // optional
  String? _avatarKey; // emoji from picker

  // Busy/error & editing
  bool _busy = false;
  String? _error;
  String? _editingMemberId;

  //Controllers
  final pinController = TextEditingController();
  final pinConfirmController = TextEditingController();

  // Repo for Firestore writes (so we get the memberId back)
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

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_editingMemberId == null) {
        // ADD: Create child (no PIN here; PIN handled per-kid via dialog)
        final newId = await _repo.addChild(
          familyId,
          displayName: _name.text.trim(),
          avatarKey: (_avatarKey?.trim().isEmpty ?? true) ? null : _avatarKey,
          pinHash: null,
        );

        // Optionally set age
        if (_age != null) {
          await _repo.updateMember(familyId, newId, {'age': _age});
        }

        _clearFormAndRefocus();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kid added')));
        }
      } else {
        // EDIT: Update existing child (still no PIN here)
        final memberId = _editingMemberId!;
        final patch = <String, dynamic>{
          'displayName': _name.text.trim(),
          if (_avatarKey != null) 'avatarKey': _avatarKey,
          if (_age != null) 'age': _age,
        };

        await _repo.updateMember(familyId, memberId, patch);

        _clearFormAndRefocus();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kid updated')));
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

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await app.removeMember(m.id);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

void _startEdit(Member m) {
    setState(() {
      _editingMemberId = m.id;
      _name.text = m.displayName;
      _avatarKey = (m.avatarKey != null && m.avatarKey!.trim().isNotEmpty)
          ? m.avatarKey
          : null;
      _age = m.age; // ✅ pre-populate from stored age, if any
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
    _nameNode.requestFocus();
  });

  void _clearFormAndRefocus() {
    _editingMemberId = null;
    _name.clear();
    _age = null;
    _avatarKey = null;
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
          builder: (ctx, setState) {
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
                        setState(() {
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
                      const SizedBox(height: 8),
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '4-digit PIN',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: pinConfirmController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Confirm PIN',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (hasExistingPin)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
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
                      // Turning PIN off
                      if (hasExistingPin) {
                        await app.updateMemberPin(memberId: m.id, pin: null);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                      return;
                    }

                    final newPin = pinController.text.trim();
                    final confirmPin = pinConfirmController.text.trim();

                    if (newPin.isEmpty && hasExistingPin) {
                      // Keep existing PIN
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                      return;
                    }

                    if (newPin.isEmpty && !hasExistingPin) {
                      setState(() {
                        error =
                            'Enter a 4-digit PIN or turn PIN off to continue.';
                      });
                      return;
                    }

                    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
                      setState(() => error = 'PIN must be exactly 4 digits.');
                      return;
                    }

                    if (newPin != confirmPin) {
                      setState(() => error = 'PINs do not match.');
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
    final kids =
        app.members
            .where((m) => m.role == FamilyRole.child && m.active)
            .toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final isEditing = _editingMemberId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids'),
        actions: [
          if (isEditing)
            TextButton.icon(
              onPressed: _busy ? null : _cancelEdit,
              icon: const Icon(Icons.clear),
              label: const Text('Cancel edit'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Simple Add/Edit Kid Card ----------
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit kid' : 'Add a kid',
                          style: ts.titleMedium,
                        ),
                        const SizedBox(height: 12),

                        // Preview avatar + name
                        Row(
                          children: [
                            CircleAvatar(
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _name,
                                focusNode: _nameNode,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  hintText: 'e.g., Sam',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final t = v?.trim() ?? '';
                                  if (t.isEmpty) {
                                    return 'Please enter a name';
                                  }
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

                        // Age + Avatar row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _age,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Age (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                items:
                                    List.generate(42, (i) => i + 3) // 3..45
                                        .map(
                                          (a) => DropdownMenuItem<int>(
                                            value: a,
                                            child: Text(a.toString()),
                                          ),
                                        )
                                        .toList(),
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _age = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Avatar',
                                  border: OutlineInputBorder(),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      (_avatarKey == null ||
                                              _avatarKey!.trim().isEmpty)
                                          ? '🙂'
                                          : _avatarKey!,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Choose emoji avatar',
                                        style: ts.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: _busy ? null : _pickAvatar,
                                      icon: const Icon(
                                        Icons.emoji_emotions_outlined,
                                      ),
                                      label: const Text('Pick'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Add / Save button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: Icon(isEditing ? Icons.save : Icons.add),
                            label: Text(isEditing ? 'Save changes' : 'Add kid'),
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _error!,
                              style: TextStyle(color: cs.error),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ---------- List ----------
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Current kids', style: ts.titleMedium),
              ),
              const SizedBox(height: 8),

              if (kids.isEmpty)
                Text(
                  'No kids yet — add one above.',
                  style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),

              ...kids.map((m) {
                final hasPin =
                    (m.pinHash != null && m.pinHash!.trim().isNotEmpty);

                return Card(
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
                                ? Icons.lock_outline_rounded
                                : Icons.lock_open_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit details',
                          onPressed: _busy ? null : () => _startEdit(m),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: _busy
                              ? null
                              : () => _removeKidFromFamily(m),
                          icon: const Icon(Icons.block),
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

/// Bottom sheet avatar picker with large tap targets and responsive grid.
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
    _selected =
        widget.initial ??
        (widget.avatars.isNotEmpty ? widget.avatars.first : '🙂');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: SizedBox(
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick an avatar', style: theme.textTheme.titleMedium),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: selected ? 2 : 1,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

// Your default avatar set (replace with your global list if you have one)
const _defaultAvatars = [
  '🦖',
  '🦄',
  '🐱',
  '🐶',
  '🐵',
  '🐼',
  '🦊',
  '🐯',
  '🐸',
  '🐨',
  '🐰',
  '🐮',
  '🐹',
  '🐻',
  '🐷',
  '🐭',
  '🦁',
  '🐔',
  '🐥',
  '🦉',
  '🦋',
  '🐞',
  '🐙',
  '🐳',
  '🚀',
  '⚽',
  '🎮',
  '🎲',
  '🎸',
  '🎯',
  '🌈',
  '🍕',
  '🍩',
  '🍪',
  '🍎',
  '🧩',
];
