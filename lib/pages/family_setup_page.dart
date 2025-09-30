import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/profile_header.dart';
import '../models/family_models.dart';
import '../state/app_state.dart';

class FamilySetupPage extends StatefulWidget {
  const FamilySetupPage({super.key});

  @override
  State<FamilySetupPage> createState() => _FamilySetupPageState();
}

class _FamilySetupPageState extends State<FamilySetupPage> {
  final _familyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  MemberRole _role = MemberRole.child;
  bool _usesThisDevice = true;
  String _avatar = '🦖';

  final _avatars = ['🦖','🦄','🐱','🐶','🐵','🐼','🦊','🐯','🐸','🐨','🐰','🐮'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Set up your family'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // FAMILY NAME
            Text('Family name', style: TextStyle(color: cs.secondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _familyCtrl,
              decoration: InputDecoration(
                hintText: 'e.g., The Parkers',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.surfaceContainerHighest),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
              ),
              onChanged: (v) => context.read<AppState>().createOrUpdateFamily(v.trim()),
            ),
            const SizedBox(height: 16),

            // PROFILE SWITCHER HEADER
            if (app.members.isNotEmpty) ...[
              Text('Profiles on this device', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const ProfileHeader(),
              const SizedBox(height: 16),
            ],

            // ADD MEMBER FORM
            _AddMemberCard(
              nameCtrl: _nameCtrl,
              role: _role,
              setRole: (r) => setState(() => _role = r),
              usesThisDevice: _usesThisDevice,
              setUsesThisDevice: (v) => setState(() => _usesThisDevice = v),
              avatar: _avatar,
              avatars: _avatars,
              setAvatar: (a) => setState(() => _avatar = a),
              onAdd: () {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) return;
                context.read<AppState>().addMember(
                      name: name,
                      role: _role,
                      avatar: _avatar,
                      usesThisDevice: _usesThisDevice,
                    );
                _nameCtrl.clear();
                _role = MemberRole.child;
                _usesThisDevice = true;
                setState(() {});
              },
            ),
            const SizedBox(height: 16),

            // MEMBERS LIST (edit role + device usage)
            if (app.members.isNotEmpty) ...[
              Text('Family members', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final m in app.members) _MemberTile(member: m),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Save & continue'),
              onPressed: () {
                // Require at least one child profile
                final hasFamily = app.family != null && app.family!.name.trim().isNotEmpty;
                final hasMember = app.members.isNotEmpty;
                if (!hasFamily || !hasMember) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(!hasFamily ? 'Please name your family' : 'Please add at least one member'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pushReplacementNamed('/home');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberCard extends StatelessWidget {
  const _AddMemberCard({
    required this.nameCtrl,
    required this.role,
    required this.setRole,
    required this.usesThisDevice,
    required this.setUsesThisDevice,
    required this.avatar,
    required this.avatars,
    required this.setAvatar,
    required this.onAdd,
  });

  final TextEditingController nameCtrl;
  final MemberRole role;
  final ValueChanged<MemberRole> setRole;
  final bool usesThisDevice;
  final ValueChanged<bool> setUsesThisDevice;
  final String avatar;
  final List<String> avatars;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.surfaceContainerHighest)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a member', style: TextStyle(color: cs.secondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.surfaceContainerHighest),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Role chips
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Parent'),
                  selected: role == MemberRole.parent,
                  onSelected: (v) => setRole(MemberRole.parent),
                ),
                ChoiceChip(
                  label: const Text('Child'),
                  selected: role == MemberRole.child,
                  onSelected: (v) => setRole(MemberRole.child),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Avatar picker
            Text('Pick an avatar', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: avatars.map((a) {
                final selected = a == avatar;
                return GestureDetector(
                  onTap: () => setAvatar(a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? cs.tertiaryContainer : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? cs.tertiary : Colors.transparent, width: 2),
                    ),
                    child: Text(a, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Device usage toggle
            Row(
              children: [
                Switch(
                  value: usesThisDevice,
                  onChanged: setUsesThisDevice,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('This user will use this device', style: TextStyle(color: cs.onSurfaceVariant))),
              ],
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Add member'),
                onPressed: onAdd,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.surfaceContainerHighest)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.role == MemberRole.child ? cs.tertiaryContainer : cs.secondaryContainer,
          child: Text(member.avatar, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(member.name),
        subtitle: Row(
          children: [
            DropdownButton<MemberRole>(
              value: member.role,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: MemberRole.parent, child: Text('Parent')),
                DropdownMenuItem(value: MemberRole.child, child: Text('Child')),
              ],
              onChanged: (r) {
                if (r != null) context.read<AppState>().updateMemberRole(member.id, r);
              },
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Switch(
                  value: member.usesThisDevice,
                  onChanged: (v) => context.read<AppState>().updateUsesThisDevice(member.id, v),
                ),
                const SizedBox(width: 4),
                const Text('Uses this device'),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => context.read<AppState>().removeMember(member.id),
        ),
        onTap: () => context.read<AppState>().setCurrentProfile(member.id),
      ),
    );
  }
}
