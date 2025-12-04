import 'package:chorezilla/pages/kid_pages/kid_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/common.dart';

class KidsHomePage extends StatelessWidget {
  const KidsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // Decide what the main content should be
    Widget content;

    if (!app.isReady) {
      content = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else {
      final kids = app.members
          .where((m) => m.role == FamilyRole.child && m.active)
          .toList();

      if (kids.isEmpty) {
        content = const Scaffold(
          body: Center(child: Text('No kids found in this family yet.')),
        );
      } else {
        content = Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false, // no back arrow
            title: const Text("Who's using Chorezilla?"),
            actions: [
              IconButton(
                icon: const Icon(Icons.lock_outline),
                tooltip: 'Parents',
                onPressed: () => _showAdultExitDialog(context),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              // Responsive column count based on available width
              int crossAxisCount;
              if (width < 500) {
                crossAxisCount = 2; // small phones
              } else if (width < 900) {
                crossAxisCount = 3; // large phones / small tablets
              } else {
                crossAxisCount = 4; // big tablets / desktop
              }

              // Slightly different aspect ratio on bigger screens
              final childAspectRatio = width < 600 ? 3 / 4 : 4 / 5;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: kids.length,
                itemBuilder: (context, index) {
                  final kid = kids[index];
                  return _KidCard(member: kid);
                },
              );
            },
          ),
        );
      }
    }

    return PopScope(canPop: false, child: content);
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Parent master PIN to exit kid mode
// ───────────────────────────────────────────────────────────────────────────

Future<void> _showAdultExitDialog(BuildContext context) async {
  final app = context.read<AppState>();

  // Safety: if for some reason there is no parent PIN yet, just switch back.
  if (!app.hasParentPin) {
    await app.setViewMode(AppViewMode.parent);
    if(!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No parent PIN set yet — going back to parent view.'),
      ),
    );
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ParentPinDialog(),
  );

  if (ok == true) {
    await app.setViewMode(AppViewMode.parent);
    // Root routing should notice viewMode == parent and show parent dashboard.
  }
}

class _ParentPinDialog extends StatefulWidget {
  const _ParentPinDialog();

  @override
  State<_ParentPinDialog> createState() => _ParentPinDialogState();
}

class _ParentPinDialogState extends State<_ParentPinDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    final pin = _controller.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'Enter your 4-digit parent PIN.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await app.verifyParentPin(pin);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      setState(() => _error = 'Incorrect PIN. Try again.');
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: cs.primaryContainer,
            child: Icon(
              Icons.lock_outline_rounded,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Parents only',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Enter your parent PIN to go back to the parent view.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Parent PIN',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Kid cards + per-kid PIN dialog
// ───────────────────────────────────────────────────────────────────────────

class _KidCard extends StatelessWidget {
  const _KidCard({required this.member});

  final Member member;

  Future<void> _handleTap(BuildContext context) async {
    final app = context.read<AppState>();

    final requiresPin = app.kidRequiresPin(member.id);
    final unlocked = app.isKidUnlocked(member.id);

    if (!requiresPin || unlocked) {
      _openKidDashboard(context, app);
      return;
    }

    final pin = await _showKidPinDialog(context, member.displayName);
    if (pin == null) return; // cancelled

    final ok = await app.verifyKidPin(memberId: member.id, pin: pin);
    if (!context.mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN. Try again.')),
      );
      return;
    }

    _openKidDashboard(context, app);
  }

  void _openKidDashboard(BuildContext context, AppState app) {
    app.setCurrentMember(member.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KidDashboardPage(memberId: member.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final avatarKey = member.avatarKey;

    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: () => _handleTap(context),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Make avatar size respond to card width
            final avatarRadius = (constraints.maxWidth * 0.25).clamp(
              48.0,
              72.0,
            );
            final emojiSize = avatarRadius * 0.9;

            // Tiny lock indicator if this kid has a PIN
            final app = context.watch<AppState>();
            final hasPin = app.kidRequiresPin(member.id);

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: cs.primaryContainer,
                      child: avatarKey != null && avatarKey.isNotEmpty
                          ? Text(
                              avatarKey,
                              style: TextStyle(
                                fontSize: emojiSize,
                                color: cs.onPrimaryContainer,
                              ),
                            )
                          : Text(
                              _initialsFor(member.displayName),
                              style: TextStyle(
                                fontSize: emojiSize * 0.7,
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    if (hasPin)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: cs.surface,
                          child: Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<String?> _showKidPinDialog(BuildContext context, String kidName) async {
  final controller = TextEditingController();

  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      return AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Enter PIN for $kidName',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter this kid’s 4-digit PIN.\nParents can also use the parent PIN.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final pin = controller.text.trim();
              Navigator.of(ctx).pop(pin.isEmpty ? null : pin);
            },
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );

  return result;
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
