import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KidJoinPage extends StatefulWidget {
  const KidJoinPage({super.key});
  @override
  State<KidJoinPage> createState() => _KidJoinPageState();
}

class _KidJoinPageState extends State<KidJoinPage> {
  final _code = TextEditingController();
  String? familyId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> members = [];

  Future<void> _ensureAnon() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

Future<void> _findFamily() async {
  await _ensureAnon();

  final code = _code.text.trim().toUpperCase();
  if (code.isEmpty && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter your family code')),
    );
    return;
  }

  final codeDoc = await FirebaseFirestore.instance
      .collection('joinCodes')
      .doc(code)
      .get();

  if (!codeDoc.exists && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code not found. Check with your parent.')),
    );
    return;
  }

  familyId = (codeDoc.data()!['familyId'] as String);

  // Now that we have familyId, we can read that family's members
  final memSnap = await FirebaseFirestore.instance
      .collection('families')
      .doc(familyId)
      .collection('members')
      .get();

  setState(() => members = memSnap.docs);
}


  Future<void> _chooseMember(String memberId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Link this anonymous user to the family & member
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'familyId': familyId,
      'role': 'kid',
      'memberId': memberId,
    }, SetOptions(merge: true));

    if (!mounted) return;
    // Send to your existing Kid Dashboard route:
    Navigator.of(context).pushReplacementNamed('/kid');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Family"),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Family code',
                hintText: 'e.g. AB7KQZ',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _findFamily,
              child: const Text('Find'),
            ),
            const SizedBox(height: 24),
            if (members.isNotEmpty) const Text('Pick your profile:'),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 12),
                itemCount: members.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (_, i) {
                  final data = members[i].data();
                  final name = (data['name'] ?? 'Kid') as String;
                  final avatar = (data['avatar'] ?? '👤') as String;
                  return InkWell(
                    onTap: () => _chooseMember(members[i].id),
                    child: Card(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(avatar, style: const TextStyle(fontSize: 44)),
                            const SizedBox(height: 8),
                            Text(name),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
