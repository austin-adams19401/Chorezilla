import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../models/family_models.dart';

class AddKidsPage extends StatefulWidget {
  const AddKidsPage({super.key});
  @override
  State<AddKidsPage> createState() => _AddKidsPageState();
}

class _AddKidsPageState extends State<AddKidsPage> {
  final _nameCtrl = TextEditingController();
  String _avatar = '🦖';
  final _avatars = ['🦖','🦄','🐱','🐶','🐵','🐼','🦊','🐯','🐸','🐨','🐰','🐮','🐷','🐤','🐙','🦁','🐢','🐞','🦉','🐝','🐬','🐧','🦋','🐳'];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _addKid() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name')));
      return;
    }
    context.read<AppState>().addMember(
      name: name,
      role: MemberRole.child,
      avatar: _avatar,
      usesThisDevice: false,
      requiresPin: false,
    );
    _nameCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Add Kids'),
        backgroundColor: cs.surface, foregroundColor: cs.onSurface, elevation: 0,
        actions: [ TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/parent'), child: const Text('Done')) ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Child name'), onSubmitted: (_) => _addKid()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _avatars.map((a) => ChoiceChip(
              label: Text(a, style: const TextStyle(fontSize: 18)),
              selected: a == _avatar,
              onSelected: (_) => setState(() => _avatar = a),
            )).toList(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _addKid, icon: const Icon(Icons.add), label: const Text('Add Kids')),
          const SizedBox(height: 24),
          const Text('Family Members'),
          const SizedBox(height: 8),
          ...app.members.map((m) => ListTile(
            leading: Text(m.avatar, style: const TextStyle(fontSize: 24)),
            title: Text(m.name),
            subtitle: Text(m.role == MemberRole.parent ? 'Parent' : 'Child'),
          )),
        ],
      ),
    );
  }
}
