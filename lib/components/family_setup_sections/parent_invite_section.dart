import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteParentsRow extends StatelessWidget {
  final String inviteCode;
  final VoidCallback onCopy;
  final Future<void> Function() onRegenerate;

  const InviteParentsRow({
    super.key,
    required this.inviteCode,
    required this.onCopy,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Invite Parents', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SelectableText('Code: $inviteCode', style: const TextStyle(fontSize: 20,fontFamily: 'monospace')),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteCode));
                onCopy();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerate'),
            ),
          ],
        ),
      ],
    );
  }
}
