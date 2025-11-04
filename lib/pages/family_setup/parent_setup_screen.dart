import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';

import 'edit_family_page.dart';
import 'add_kids_page.dart';

class ParentSetupPage extends StatelessWidget {
  const ParentSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final family = app.family;
    final kids = app.members.where((m) => m.role == FamilyRole.child && m.active).toList();
    debugPrint(kids.toString());

    return Scaffold(
      appBar: AppBar(title: const Text('Family Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (family != null) ...[
              Text('Welcome to ${family.name}!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Let’s finish setting up your family so everyone can start earning points.'),
              const SizedBox(height: 16),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.family_restroom_rounded),
                title: const Text('Edit family details'),
                subtitle: const Text('Rename your family, get invite code'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditFamilyPage()));
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.child_care_rounded),
                title: Text(kids.isEmpty ? 'Add your kids' : 'Manage kids'),
                subtitle: Text(kids.isEmpty
                    ? 'Create a profile for each child'
                    : 'You have ${kids.length} kid${kids.length == 1 ? "" : "s"} added'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddKidsPage()));
                },
              ),
            ),
            const Spacer(),
            if (kids.isEmpty)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddKidsPage()));
                },
                child: const Text('Add a kid to get started'),
              ),
          ],
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../z_archive/app_state_old.dart';

// class ParentSetupPage extends StatefulWidget {
//   const ParentSetupPage({super.key});
//   @override
//   State<ParentSetupPage> createState() => _ParentSetupPageState();
// }

// class _ParentSetupPageState extends State<ParentSetupPage> {
//   final _parentCtrl = TextEditingController();
//   final _familyCtrl = TextEditingController();
//   bool _busy = false;

//   @override
//   void dispose() { _parentCtrl.dispose(); _familyCtrl.dispose(); super.dispose(); }

//   Future<void> _createFamily() async {
//     if (_parentCtrl.text.trim().isEmpty || _familyCtrl.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name and a family name')));
//       return;
//     }
//     setState(() => _busy = true);
//     try {
//       await context.read<AppState>().createFamily(
//         initialMembers: [],
//         familyName: _familyCtrl.text.trim(),
//       );
//       if (!mounted) return;
//       Navigator.pushReplacementNamed(context, '/add-kids');
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _invite() async {
//     try {
//       final code = await context.read<AppState>().createInvite();
//       if (!mounted) return;
//       showDialog(context: context, builder: (_) => AlertDialog(
//         title: const Text('Invite Co-Parent'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text('Share this one-time code:'),
//             const SizedBox(height: 8),
//             SelectableText(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
//           ],
//         ),
//         actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')) ],
//       ));
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
//     }
//   }

//   Future<void> _showJoinDialog() async {
//     final ctrl = TextEditingController();
//     showDialog(context: context, builder: (_) => AlertDialog(
//       title: const Text('Join Family'),
//       content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Invite Code')),
//       actions: [
//         TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//         TextButton(onPressed: () async {
//           final code = ctrl.text.trim();
//           Navigator.pop(context);
//           try {
//             await context.read<AppState>().redeemInvite(code, parentDisplayName: _parentCtrl.text.trim().isEmpty ? 'Parent' : _parentCtrl.text.trim());
//             if (!mounted) return;
//             Navigator.pushReplacementNamed(context, '/dashboard');
//           } catch (e) {
//             if (!mounted) return;
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
//           }
//         }, child: const Text('Join')),
//       ],
//     ));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Scaffold(
//       backgroundColor: cs.surface,
//       appBar: AppBar(
//         title: const Text('Parent & Family Setup'),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//         elevation: 0,
//       ),
//       body: SafeArea(
//         child: ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             TextField(controller: _parentCtrl, decoration: const InputDecoration(labelText: 'Your name (parent)')),
//             const SizedBox(height: 12),
//             TextField(controller: _familyCtrl, decoration: const InputDecoration(labelText: 'Family name')),
//             const SizedBox(height: 24),
//             FilledButton.icon(
//               onPressed: _busy ? null : _createFamily,
//               icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.family_restroom),
//               label: const Text('Create Family'),
//             ),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(child: OutlinedButton.icon(onPressed: _invite, icon: const Icon(Icons.link), label: const Text('Invite Co-Parent'))),
//                 const SizedBox(width: 12),
//                 Expanded(child: OutlinedButton.icon(onPressed: _showJoinDialog, icon: const Icon(Icons.qr_code), label: const Text('I have a code'))),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
