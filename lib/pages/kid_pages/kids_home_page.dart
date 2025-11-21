import 'package:chorezilla/pages/kid_pages/child_dashboard.dart';
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
          body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 3 / 4,
            ),
            itemCount: kids.length,
            itemBuilder: (context, index) {
              final kid = kids[index];
              return _KidCard(member: kid);
            },
          ),
        );
      }
    }

    return PopScope(
      canPop: false, 
      // onPopInvokedWithResult: (didPop) {
      //   debugPrint('Tried to pop kid mode: didPop=$didPop');
      // },
      child: content,
    );
  }


Future<void> _showAdultExitDialog(BuildContext context) async {
    final controller = TextEditingController();
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const correctAnswer = '144'; // 12 x 12

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.lock_outline_rounded, color: cs.onPrimaryContainer),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Grown-ups: 👀',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'To go back to the parent view, answer this question:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calculate_rounded, color: cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'What is 12 × 12?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  border: UnderlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim() == correctAnswer) {
                  // Correct → close this dialog, result = true
                  Navigator.of(ctx).pop(true);
                } else {
                  // Incorrect → show styled "Nice try" dialog, keep main dialog open
                  showDialog<void>(
                    context: ctx,
                    builder: (errCtx) {
                      final errTheme = Theme.of(errCtx);
                      final errCs = errTheme.colorScheme;
                      return AlertDialog(
                        backgroundColor: errCs.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        contentPadding: const EdgeInsets.fromLTRB(
                          24,
                          12,
                          24,
                          16,
                        ),
                        actionsPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        title: Row(
                          children: [                            
                            Text(
                              'Nice try… 😏',
                              style: errTheme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          "Are you sure you're a parent??",
                          style: errTheme.textTheme.bodyMedium?.copyWith(
                            color: errCs.onSurfaceVariant,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(errCtx).pop(),
                            child: const Text('Yes, let me try again'),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              Navigator.of(errCtx).pop();
                              Navigator.of(ctx).pop(false);
                            },
                            child: const Text("I'm just a kid"),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      navigator.pop();
    }
  }
}

class _KidCard extends StatelessWidget {
  const _KidCard({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final avatarKey = member.avatarKey;
    const double avatarRadius = 64;
    final double emojiSize = avatarRadius * 0.9;

    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: () {
        app.setCurrentMember(member.id);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChildDashboardPage(memberId: member.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: cs.primaryContainer,
              child: avatarKey != null && avatarKey.isNotEmpty
                ? Text(
                    avatarKey,
                    style: TextStyle(
                      fontSize: emojiSize, // 👈 bigger emoji
                      color: cs.onPrimaryContainer,
                    ),
                  )
                : Text(
                    _initialsFor(member.displayName),
                    style: TextStyle(
                      fontSize: emojiSize * 0.7, // initials a bit smaller
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}


  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

