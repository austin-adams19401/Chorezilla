import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class KidJoinPage extends StatefulWidget {
  const KidJoinPage({super.key});
  @override
  State<KidJoinPage> createState() => _KidJoinPageState();
}

class _KidJoinPageState extends State<KidJoinPage> {
  final _code = TextEditingController();
  final _repo = ChorezillaRepo(firebaseDB: FirebaseFirestore.instance);

  String? familyId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> members = [];
  bool _searching = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _ensureAnon() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<void> _findFamily() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your family code')),
      );
      return;
    }

    setState(() { _searching = true; });

    try {
      await _ensureAnon();

      final codeDoc = await FirebaseFirestore.instance
          .collection('joinCodes')
          .doc(code)
          .get();

      if (!mounted) return;

      if (!codeDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code not found. Check with your parent.')),
        );
        return;
      }

      final resolvedFamilyId = codeDoc.data()!['familyId'] as String;

      final memSnap = await FirebaseFirestore.instance
          .collection('families')
          .doc(resolvedFamilyId)
          .collection('members')
          .where('role', isEqualTo: 'child')
          .where('active', isEqualTo: true)
          .get();

      if (!mounted) return;
      setState(() {
        familyId = resolvedFamilyId;
        members = memSnap.docs;
      });
    } finally {
      if (mounted) setState(() { _searching = false; });
    }
  }

  Future<void> _scanQrCode() async {
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QrScannerSheet(),
    );
    if (scanned != null && scanned.isNotEmpty) {
      _code.text = scanned;
      _findFamily();
    }
  }

  Future<void> _chooseMember(String memberId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Write both familyId (legacy) and defaultFamilyId so that
    // _getDataForUser can find the family and start streams.
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'familyId': familyId,
      'defaultFamilyId': familyId,
      'role': 'kid',
      'memberId': memberId,
    }, SetOptions(merge: true));

    if (!mounted) return;
    final app = context.read<AppState>();

    // Mark this device as kid-view so AuthGate routes correctly.
    await app.setViewMode(AppViewMode.kid);

    // Re-read the profile now that defaultFamilyId is set — this starts the
    // family streams and gets bootLoaded to true so AuthGate can route.
    await app.refreshAfterProfileChange();

    if (!mounted) return;
    // Go back to root and let AuthGate handle routing once streams are ready.
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _createAndJoin() async {
    // Use the signed-in display name if available (registered user flow).
    // Only prompt if the user is anonymous and has no name yet.
    final existingName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    String? name;

    if (existingName != null && existingName.isNotEmpty) {
      name = existingName;
    } else {
      final nameController = TextEditingController();
      try {
        name = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => _NewKidSheet(controller: nameController),
        );
      } finally {
        nameController.dispose();
      }
    }

    if (!mounted || name == null || name.isEmpty) return;

    setState(() { _searching = true; });
    try {
      final newId = await _repo.addChild(
        familyId!,
        displayName: name,
        avatarKey: null,
        pinHash: null,
      );
      await _chooseMember(newId);
    } finally {
      if (mounted) setState(() { _searching = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFamily = familyId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Family code',
                hintText: 'e.g. AB7KQZ',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan QR code',
                  onPressed: _scanQrCode,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _searching ? null : _findFamily,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Find Family'),
            ),
            TextButton(
              onPressed: () async {
                if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
                  await FirebaseAuth.instance.signOut();
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            if (hasFamily) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Pick your profile:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  itemCount: members.length + 1,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (_, i) {
                    if (i == members.length) {
                      // "+" card — create new kid profile
                      return InkWell(
                        onTap: _createAndJoin,
                        borderRadius: BorderRadius.circular(12),
                        child: Card(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    size: 36, color: cs.primary),
                                const SizedBox(height: 6),
                                Text(
                                  "I'm not listed",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: cs.primary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final data = members[i].data();
                    final name = (data['displayName'] ?? 'Kid') as String;
                    final avatarKey = data['avatarKey'] as String?;

                    return InkWell(
                      onTap: () => _chooseMember(members[i].id),
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _AvatarWidget(avatarKey: avatarKey, name: name),
                            const SizedBox(height: 6),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class _NewKidSheet extends StatelessWidget {
  const _NewKidSheet({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "What's your name?",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Your first name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              final name = v.trim();
              if (name.isNotEmpty) Navigator.of(context).pop(name);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(context).pop(name);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.avatarKey, required this.name});

  final String? avatarKey;
  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (avatarKey != null && avatarKey!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/avatars/$avatarKey',
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, _) => CircleAvatar(
            radius: 26,
            backgroundColor: cs.primaryContainer,
            child: Text(initial,
                style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: cs.primaryContainer,
      child: Text(initial,
          style: TextStyle(
              color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
    );
  }
}

class _QrScannerSheet extends StatefulWidget {
  const _QrScannerSheet();

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          AppBar(
            title: const Text('Scan Family Code'),
            leading: CloseButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            automaticallyImplyLeading: false,
          ),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_detected) return;
                final raw = capture.barcodes.first.rawValue;
                if (raw == null) return;
                _detected = true;
                // Trim to 6-char alphanumeric code in case of any prefix
                final code = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                final joinCode = code.length >= 6 ? code.substring(code.length - 6) : code;
                Navigator.of(context).pop(joinCode);
              },
            ),
          ),
        ],
      ),
    );
  }
}
