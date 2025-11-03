import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/family.dart';

class ParentJoinPage extends StatefulWidget {
  const ParentJoinPage({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<ParentJoinPage> createState() => _ParentJoinPageState();
}

class _ParentJoinPageState extends State<ParentJoinPage> {
  final _code = TextEditingController();
  String? _familyId;
  Family? _family;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _code.text = widget.initialCode!;
      _lookup();
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() { _busy = true; _familyId = null; _family = null; _error = null; });
    try {
      final repo = context.read<AppState>().repo;
      final code = _code.text.trim().toUpperCase();
      final famId = await repo.redeemJoinCode(code);
      if (famId == null) {
        setState(() { _error = 'Invalid or expired code'; });
        return;
      }
      // fetch family once to show name
      final fam = await repo.watchFamily(famId).first;
      setState(() { _familyId = famId; _family = fam; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _busy = false; });
    }
  }

  Future<void> _join() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _familyId == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final app = context.read<AppState>();
      final repo = app.repo;
      await repo.joinFamilyAsParent(
        familyId: _familyId!,
        uid: user.uid,
        displayName: user.displayName,
      );
      await app.refreshAfterProfileChange();
      if (!mounted) return;
      // Go back to the root; AuthGate will now show the new family's dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Your Family')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite code',
                hintText: 'e.g., 7K3XQ9',
              ),
              onSubmitted: (_) => _lookup(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : _lookup,
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Check'),
                ),
                const SizedBox(width: 12),
                if (_family != null)
                  Text('Found: ${_family!.name}', style: ts.bodyMedium),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 24),
            if (_family != null)
              FilledButton.tonal(
                onPressed: _busy ? null : _join,
                child: const Text('Join as Parent'),
              ),
          ],
        ),
      ),
    );
  }
}
