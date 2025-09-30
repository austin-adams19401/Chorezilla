import 'package:flutter/material.dart';
import 'package:chorezilla/models/chore_models.dart';
import 'package:chorezilla/models/family_models.dart';

class ChoreCard extends StatelessWidget {
  const ChoreCard({super.key, required this.chore, required this.assignees});

  final Chore chore;
  final List<Member> assignees;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.surfaceContainerHighest),
      ),
      child: ListTile(
        leading: chore.icon != null
            ? CircleAvatar(
                backgroundColor: cs.secondaryContainer,
                child: Icon(
                  chore.icon,
                  color: chore.iconColor ?? cs.onSecondaryContainer, // <-- use saved color
                ),
              )
            : null,
        title: Text(chore.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${chore.points} pts • ${chore.frequency.name}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...assignees.take(4).map((m) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: m.role == MemberRole.child ? cs.tertiaryContainer : cs.secondaryContainer,
                child: Text(m.avatar, style: const TextStyle(fontSize: 16)),
              ),
            )),
            if (assignees.length > 4)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('+${assignees.length - 4}', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}
