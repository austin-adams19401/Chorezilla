import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/member.dart';

class AddKidsPage extends StatefulWidget {
  const AddKidsPage({super.key});

  @override
  State<AddKidsPage> createState() => _AddKidsPageState();
}

class _AddKidsPageState extends State<AddKidsPage> {
  final _name = TextEditingController();
  final _avatar = TextEditingController(); // emoji or short text
  final _pin = TextEditingController();    // optional; stored as pinHash field for now (TODO: hash)
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _avatar.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _addKid() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      // Note: we're storing the raw PIN as pinHash for now. Replace with a hash if you add a crypto dep.
      await context.read<AppState>().addChild(
            name: _name.text.trim(),
            avatarKey: _avatar.text.trim().isEmpty ? null : _avatar.text.trim(),
            pinHash: _pin.text.trim().isEmpty ? null : _pin.text.trim(),
          );
      if (!mounted) return;
      _name.clear();
      _avatar.clear();
      _pin.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kid added')));
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _deactivateKid(Member m) async {
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AppState>().updateMember(m.id, {'active': false});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deactivated ${m.displayName}')));
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final kids = app.members.where((m) => m.role == FamilyRole.child && m.active).toList();
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kids')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Add a kid', style: ts.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _avatar,
                  decoration: const InputDecoration(
                    labelText: 'Avatar (emoji)',
                    hintText: 'e.g., 🦖',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PIN (optional)',
                    hintText: '4-6 digits',
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _busy ? null : _addKid,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text('Current kids', style: ts.titleMedium),
          const SizedBox(height: 8),
          if (kids.isEmpty)
            Text('No kids yet — add one above.', style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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
                  trailing: IconButton(
                    tooltip: 'Deactivate',
                    onPressed: _busy ? null : () => _deactivateKid(m),
                    icon: const Icon(Icons.block),
                  ),
                ),
              )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _initial(String name) {
    final n = name.trim();
    return n.isEmpty ? '?' : n.characters.first.toUpperCase();
  }
}


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
