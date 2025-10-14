import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';

class EditFamilyPage extends StatefulWidget {
  const EditFamilyPage({super.key});

  @override
  State<EditFamilyPage> createState() => _EditFamilyPageState();
}

class _EditFamilyPageState extends State<EditFamilyPage> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _name.text = app.family?.name ?? 'My Family';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final app = context.read<AppState>();
    final famId = app.familyId;
    if (famId == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await app.repo.updateFamily(famId, {'name': _name.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      Navigator.of(context).maybePop();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _getInviteCode() async {
    final app = context.read<AppState>();
    setState(() { _busy = true; _error = null; });
    try {
      final code = await app.ensureJoinCode(); // calls repo.ensureJoinCode under the hood
      setState(() { _code = code; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _copyCode() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: _code!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Family')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Family name', hintText: 'e.g., The Sorianos'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _saveName,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
          const SizedBox(height: 32),
          Text('Invite another parent', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: _busy ? null : _getInviteCode,
                child: const Text('Get invite code'),
              ),
              const SizedBox(width: 12),
              if (_code != null)
                SelectableText(
                  _code!,
                  style: TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const Spacer(),
              if (_code != null)
                IconButton(
                  tooltip: 'Copy',
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with a parent you want to add. They will use it on the “Join Family” screen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}


// // lib/pages/family/edit_family_page.dart
// import 'package:chorezilla/components/family_setup_sections/family_name_section.dart';
// import 'package:chorezilla/components/family_setup_sections/kid_picker.dart';
// import 'package:chorezilla/components/family_setup_sections/kids_list.dart';
// import 'package:chorezilla/components/family_setup_sections/parent_invite_section.dart';
// import 'package:chorezilla/z_archive/app_state_old.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// class EditFamilyPage extends StatefulWidget {
//   const EditFamilyPage({super.key});
//   @override
//   State<EditFamilyPage> createState() => _EditFamilyPageState();
// }

// class _EditFamilyPageState extends State<EditFamilyPage> {
//   String? _pendingName;
//   bool _savingName = false;
//   String _inviteCode = '…';

//   static const _avatars = [
//     '🦖','🦄','🐱','🐶','🐵','🐼','🦊','🐯','🐸','🐨','🐰','🐮',
//     '🐷','🐤','🐙','🦁','🐢','🐞','🦉','🐝','🐬','🐧','🦋','🐳'
//   ];

//   @override
//   void initState() {
//     super.initState();
//     // If family isn’t yet hydrated, this will still run shortly after.
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       final app = context.read<AppState>();
//       try {
//         final code = await app.createInvite(); // your existing helper
//         if (mounted) setState(() => _inviteCode = code);
//       } catch (_) {
//         if (mounted) setState(() => _inviteCode = '—');
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final fam = app.family;
//     final currentName = _pendingName ?? (fam?['name'] as String);

//     // Split parents/kids from your hydrated members
//     final parents = app.members.where((m) => m.role.toString().contains('parent')).toList();
//     final kids = app.members.where((m) => m.role.toString().contains('child')).toList();

//     return Scaffold(
//       appBar: AppBar(title: const Text('Edit Family')),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           // 1) Family Name
//           FamilyNameRow(
//             initialName: currentName,
//             saving: _savingName,
//             onChanged: (v) => _pendingName = v,
//             onSave: () async {
//               final toSave = (_pendingName ?? currentName).trim();
//               if (toSave.isEmpty) return;
//               setState(() => _savingName = true);
//               try {
//                 await app.updateFamilyName(toSave);
//                 _pendingName = null;
//                 if (context.mounted) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Family name updated')),
//                   );
//                 }
//               } finally {
//                 if (mounted) setState(() => _savingName = false);
//               }
//             },
//           ),

//           const SizedBox(height: 12),

//           // 2) Invite Parents (also shows current parents for clarity)
//           const SizedBox(height: 12),
//           InviteParentsRow(
//             inviteCode: _inviteCode,
//             onCopy: () {}, // snackbar handled inside the row
//             onRegenerate: () async {
//               await app.rotateInviteCode();
//               final code = await app.createInvite(); // fetch fresh
//               if (mounted) setState(() => _inviteCode = code);
//             },
//           ),
//           if (parents.isNotEmpty) ...[
//             const SizedBox(height: 8),
//             const Text('Current Parents', style: TextStyle(fontWeight: FontWeight.w600)),
//             const SizedBox(height: 4),
//             ...parents.map((p) => ListTile(
//                   dense: true,
//                   contentPadding: EdgeInsets.zero,
//                   leading: Text(p.avatar, style: const TextStyle(fontSize: 22)),
//                   title: Text(p.name),
//                 )),
//           ],

//           const SizedBox(height: 12),

//           // 3) Add Kid picker
//           const SizedBox(height: 12),
//           AddKidPickerRow(
//             avatars: _avatars,
//             onAdd: ({required String name, required String avatar}) async {
//               await app.addChild(name: name, avatar: avatar);
//             },
//           ),

//           const SizedBox(height: 12),
//           const Divider(),

//           // 4) List of current kids
//           const SizedBox(height: 12),
//           KidsListRow(
//             kids: kids.map((k) => KidItem(
//               id: k.id,
//               name: k.name,
//               avatar: k.avatar,
//               role: 'child',
//             )).toList(),
//             onRemove: (kidId) => app.removeChild(kidId: kidId),
//           ),
//         ],
//       ),
//     );
//   }
// }
