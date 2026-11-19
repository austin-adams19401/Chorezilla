import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:chorezilla/services/backend_functions.dart';
import 'package:chorezilla/state/app_state.dart';

class ParentJoinPage extends StatefulWidget {
  const ParentJoinPage({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<ParentJoinPage> createState() => _ParentJoinPageState();
}

class _ParentJoinPageState extends State<ParentJoinPage> {
  final _code = TextEditingController();
  String? _familyId;
  String? _familyName;
  String? _codeKind;
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
    setState(() {
      _busy = true;
      _familyId = null;
      _familyName = null;
      _codeKind = null;
      _error = null;
    });
    try {
      final preview = await BackendFunctions.previewJoinCode(_code.text);
      if (preview.familyId.isEmpty) {
        setState(() { _error = 'Invalid or expired code'; });
        return;
      }
      if (preview.kind == 'child') {
        setState(() {
          _error = 'That code is for a kid. Ask a parent for a parent invite.';
        });
        return;
      }
      setState(() {
        _familyId = preview.familyId;
        _familyName = preview.familyName;
        _codeKind = preview.kind;
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _busy = false; });
    }
  }

  Future<void> _join() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      debugPrint(
        'JOIN AS PARENT: familyId=$_familyId user=$user displayName="${user.displayName}"',
      );

      final app = context.read<AppState>();
      if (_codeKind == 'parent') {
        await BackendFunctions.joinWithFamilyCode(
          code: _code.text,
          kind: 'parent',
          displayName: user.displayName,
        );
      } else if (_codeKind == 'invite') {
        await BackendFunctions.redeemParentInvite(
          code: _code.text,
          displayName: user.displayName,
        );
      } else if (_codeKind == 'child') {
        throw Exception(
          'That code is for a kid device. Use the parent invite code.',
        );
      } else {
        await BackendFunctions.redeemParentInvite(
          code: _code.text,
          displayName: user.displayName,
        );
      }
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
                if (_familyName != null)
                  Text('Found: $_familyName', style: ts.bodyMedium),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 24),
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
