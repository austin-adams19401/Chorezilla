import 'package:chorezilla/components/premium_upgrade_sheet.dart';
import 'package:chorezilla/data/chorezilla_repo.dart';
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
      final code = await app.ensureJoinCode();
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final isPremium = app.family?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Family'),
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Family name ────────────────────────────────────────────────
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Family name',
              hintText: 'e.g., The Sorianos',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _saveName,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Invite another parent ──────────────────────────────────────
          Row(
            children: [
              Text('Invite another parent', style: ts.titleMedium),
              const SizedBox(width: 8),
              if (!isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded,
                          size: 13, color: Colors.amber.shade800),
                      const SizedBox(width: 3),
                      Text(
                        'Premium',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (!isPremium) ...[
            // ── Locked state ───────────────────────────────────────────
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showPremiumUpgradeSheet(
                context,
                reason: UpgradeReason.parentAccount,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('👑', style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add a co-parent to your family',
                            style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Upgrade to Premium to invite another parent.',
                            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ] else ...[
            // ── Unlocked state ─────────────────────────────────────────
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
              'Share this code with a parent you want to add. They will use it on the "Join Family" screen.',
              style: ts.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
