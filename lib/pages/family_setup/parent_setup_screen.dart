import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';

class ParentSetupScreen extends StatefulWidget {
  const ParentSetupScreen({super.key});
  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final _parentCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() { _parentCtrl.dispose(); _familyCtrl.dispose(); super.dispose(); }

  Future<void> _createFamily() async {
    if (_parentCtrl.text.trim().isEmpty || _familyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name and a family name')));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().createFamily(
        initialMembers: [],
        familyName: _familyCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/add-kids');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    try {
      final code = await context.read<AppState>().createInvite();
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Invite Co-Parent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this one-time code:'),
            const SizedBox(height: 8),
            SelectableText(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')) ],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showJoinDialog() async {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Join Family'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Invite Code')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () async {
          final code = ctrl.text.trim();
          Navigator.pop(context);
          try {
            await context.read<AppState>().redeemInvite(code, parentDisplayName: _parentCtrl.text.trim().isEmpty ? 'Parent' : _parentCtrl.text.trim());
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/dashboard');
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }, child: const Text('Join')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Parent & Family Setup'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _parentCtrl, decoration: const InputDecoration(labelText: 'Your name (parent)')),
            const SizedBox(height: 12),
            TextField(controller: _familyCtrl, decoration: const InputDecoration(labelText: 'Family name')),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _createFamily,
              icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.family_restroom),
              label: const Text('Create Family'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _invite, icon: const Icon(Icons.link), label: const Text('Invite Co-Parent'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: _showJoinDialog, icon: const Icon(Icons.qr_code), label: const Text('I have a code'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
