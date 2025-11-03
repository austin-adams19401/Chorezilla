import 'dart:math' as math;
import 'package:chorezilla/firebase_queries/chorezilla_repo.dart';
import 'package:flutter/material.dart';
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
  int? _age;              // optional
  String? _avatarKey;     // emoji from picker

  // Busy/error & editing
  bool _busy = false;
  String? _error;
  String? _editingMemberId;

  // Repo for Firestore writes (so we get the memberId back)
  final ChorezillaRepo _repo = ChorezillaRepo(firebaseDB: FirebaseFirestore.instance);

  @override
  void dispose() {
    _name.dispose();
    _nameNode.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AvatarPickerSheet(
        avatars: _defaultAvatars,
        initial: _avatarKey,
      ),
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

    setState(() { _busy = true; _error = null; });

    try {
      if (_editingMemberId == null) {
        // ADD: Create child (no PIN on this screen)
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
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(content: Text('Kid added')),
        //   );
        // }
      } else {
        // EDIT: Update existing child
        final patch = <String, dynamic>{
          'displayName': _name.text.trim(),
          if (_avatarKey != null) 'avatarKey': _avatarKey,
          if (_age != null) 'age': _age,
        };

        await _repo.updateMember(familyId, _editingMemberId!, patch);

        _clearFormAndRefocus();
        if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Kid updated')),
          // );
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
    if(familyId == null || familyId.isEmpty) return;

    setState(() {
      _busy = true; _error = null;
    });

    try {
      await app.removeMember(m.id);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if(mounted) {
        setState(() { _busy = false; });
      }
    }
  }

  void _startEdit(Member m) {
    setState(() {
      _editingMemberId = m.id;
      _name.text = m.displayName;
      _avatarKey = (m.avatarKey != null && m.avatarKey!.trim().isNotEmpty) ? m.avatarKey : null;
      _age = null;
    });
    // Put focus on name for quick edits
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final kids = app.members
        .where((m) => m.role == FamilyRole.child && m.active)
        .toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids'),
        actions: [
          if (_editingMemberId != null)
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
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: cs.tertiaryContainer,
                            child: Text(
                              (_avatarKey == null || _avatarKey!.trim().isEmpty)
                                  ? _initial(_name.text)
                                  : _avatarKey!,
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Preview', style: ts.labelMedium),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
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
                        if (t.isEmpty) return 'Please enter a name';
                        if (t.length > 30) return 'Keep it under 30 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age (optional)
                    DropdownButtonFormField<int>(
                      initialValue: _age,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(16, (i) => i + 3) // 3..18
                          .map((a) => DropdownMenuItem<int>(
                                value: a,
                                child: Text(a.toString()),
                              ))
                          .toList(),
                      onChanged: _busy ? null : (v) => setState(() => _age = v),
                      validator: (v) => v == null ? 'Please select an age' : null
                    ),
                    const SizedBox(height: 16),

                    // Avatar Picker
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Avatar',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Text(
                            (_avatarKey == null || _avatarKey!.trim().isEmpty)
                                ? '🙂'
                                : _avatarKey!,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Choose an emoji avatar',
                              style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _pickAvatar,
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            label: const Text('Pick'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Add / Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: Icon(_editingMemberId == null ? Icons.add : Icons.save),
                        label: Text(_editingMemberId == null ? 'Add Kid' : 'Save Changes'),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_error!, style: TextStyle(color: cs.error)),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ---------- List ----------
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Current Kids', style: ts.titleMedium),
              ),
              const SizedBox(height: 8),

              if (kids.isEmpty)
                Text(
                  'No kids yet — add one above.',
                  style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),

              ...kids.map((m) => Card(
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
                      subtitle: Text('Level ${m.level} • ${m.xp} XP • ${m.coins} coins'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: _busy ? null : () => _startEdit(m),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: _busy ? null : () => _removeKidFromFamily(m),
                            icon: const Icon(Icons.block),
                          ),
                        ],
                      ),
                    ),
                  )),

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
  const _AvatarPickerSheet({
    required this.avatars,
    this.initial,
  });

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
    _selected = widget.initial ?? (widget.avatars.isNotEmpty ? widget.avatars.first : '🙂');
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
                  final count = math.max(4, math.min(8, (constraints.maxWidth / 64).floor()));
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
                  label: const Text('Use Avatar'),
                )
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
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

// Your default avatar set (replace with your global list if you have one)
const _defaultAvatars = [
  '🦖','🦄','🐱','🐶','🐵','🐼','🦊','🐯','🐸','🐨','🐰','🐮',
  '🐹','🐻','🐷','🐭','🦁','🐔','🐥','🦉','🦋','🐞','🐙','🐳',
  '🚀','⚽','🎮','🎲','🎸','🎯','🌈','🍕','🍩','🍪','🍎','🧩',
];

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../z_archive/app_state_old.dart';

// class AddKidsPage extends StatefulWidget {
//   const AddKidsPage({super.key});
//   @override
//   State<AddKidsPage> createState() => _AddKidsPageState();
// }

// class _AddKidsPageState extends State<AddKidsPage> {
//   final _nameCtrl = TextEditingController();
//   String _avatar = '🦖';
//   final _avatars = ['🦖','🦄','🐱','🐶','🐵','🐼','🦊','🐯','🐸','🐨','🐰','🐮','🐷','🐤','🐙','🦁','🐢','🐞','🦉','🐝','🐬','🐧','🦋','🐳'];

//   @override
//   void dispose() { _nameCtrl.dispose(); super.dispose(); }

//   Future<void> _addKid() async {
//     final name = _nameCtrl.text.trim();
//     if (name.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name')));
//       return;
//     }
//     context.read<AppState>().addMember(
//       name: name,
//       role: MemberRole.child,
//       avatar: _avatar,
//       usesThisDevice: false,
//       requiresPin: false,
//     );
//     _nameCtrl.clear();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final cs = Theme.of(context).colorScheme;

//     return Scaffold(
//       backgroundColor: cs.surface,
//       appBar: AppBar(
//         title: const Text('Add Kids'),
//         backgroundColor: cs.surface, foregroundColor: cs.onSurface, elevation: 0,
//         actions: [ TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/parent'), child: const Text('Done')) ],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Child name'), onSubmitted: (_) => _addKid()),
//           const SizedBox(height: 12),
//           Wrap(
//             spacing: 8, runSpacing: 8,
//             children: _avatars.map((a) => ChoiceChip(
//               label: Text(a, style: const TextStyle(fontSize: 18)),
//               selected: a == _avatar,
//               onSelected: (_) => setState(() => _avatar = a),
//             )).toList(),
//           ),
//           const SizedBox(height: 12),
//           FilledButton.icon(onPressed: _addKid, icon: const Icon(Icons.add), label: const Text('Add Kids')),
//           const SizedBox(height: 24),
//           const Text('Family Members'),
//           const SizedBox(height: 8),
//           ...app.members.map((m) => ListTile(
//             leading: Text(m.avatar, style: const TextStyle(fontSize: 24)),
//             title: Text(m.name),
//             subtitle: Text(m.role == MemberRole.parent ? 'Parent' : 'Child'),
//           )),
//         ],
//       ),
//     );
//   }
// }
