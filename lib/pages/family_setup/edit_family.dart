// lib/pages/family/edit_family_page.dart
import 'package:chorezilla/components/family_setup_sections/family_name_section.dart';
import 'package:chorezilla/components/family_setup_sections/kid_picker.dart';
import 'package:chorezilla/components/family_setup_sections/kids_list.dart';
import 'package:chorezilla/components/family_setup_sections/parent_invite_section.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditFamilyPage extends StatefulWidget {
  const EditFamilyPage({super.key});
  @override
  State<EditFamilyPage> createState() => _EditFamilyPageState();
}

class _EditFamilyPageState extends State<EditFamilyPage> {
  String? _pendingName;
  bool _savingName = false;
  String _inviteCode = '…';

  static const _avatars = [
    '🦖','🦄','🐱','🐶','🐵','🐼','🦊','🐯','🐸','🐨','🐰','🐮',
    '🐷','🐤','🐙','🦁','🐢','🐞','🦉','🐝','🐬','🐧','🦋','🐳'
  ];

  @override
  void initState() {
    super.initState();
    // Get or create the code once we have family in state.
    // If family isn’t yet hydrated, this will still run shortly after.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      try {
        final code = await app.createInvite(); // your existing helper
        if (mounted) setState(() => _inviteCode = code);
      } catch (_) {
        if (mounted) setState(() => _inviteCode = '—');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fam = app.family;
    final currentName = _pendingName ?? (fam?['name'] as String);

    // Split parents/kids from your hydrated members
    final parents = app.members.where((m) => m.role.toString().contains('parent')).toList();
    final kids = app.members.where((m) => m.role.toString().contains('child')).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Family')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1) Family Name
          FamilyNameRow(
            initialName: currentName,
            saving: _savingName,
            onChanged: (v) => _pendingName = v,
            onSave: () async {
              final toSave = (_pendingName ?? currentName).trim();
              if (toSave.isEmpty) return;
              setState(() => _savingName = true);
              try {
                await app.updateFamilyName(toSave);
                _pendingName = null;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Family name updated')),
                  );
                }
              } finally {
                if (mounted) setState(() => _savingName = false);
              }
            },
          ),

          const SizedBox(height: 12),

          // 2) Invite Parents (also shows current parents for clarity)
          const SizedBox(height: 12),
          InviteParentsRow(
            inviteCode: _inviteCode,
            onCopy: () {}, // snackbar handled inside the row
            onRegenerate: () async {
              await app.rotateInviteCode();
              final code = await app.createInvite(); // fetch fresh
              if (mounted) setState(() => _inviteCode = code);
            },
          ),
          if (parents.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Current Parents', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...parents.map((p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text(p.avatar, style: const TextStyle(fontSize: 22)),
                  title: Text(p.name),
                )),
          ],

          const SizedBox(height: 12),

          // 3) Add Kid picker
          const SizedBox(height: 12),
          AddKidPickerRow(
            avatars: _avatars,
            onAdd: ({required String name, required String avatar}) async {
              await app.addChild(name: name, avatar: avatar);
            },
          ),

          const SizedBox(height: 12),
          const Divider(),

          // 4) List of current kids
          const SizedBox(height: 12),
          KidsListRow(
            kids: kids.map((k) => KidItem(
              id: k.id,
              name: k.name,
              avatar: k.avatar,
              role: 'child',
            )).toList(),
            onRemove: (kidId) => app.removeChild(kidId: kidId),
          ),
        ],
      ),
    );
  }
}
