import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';

class ChoresNavIcon extends StatelessWidget {
  const ChoresNavIcon({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<List<Assignment>>(
      valueListenable: app.reviewQueueVN,
      builder: (_, queue, _) {
        final hasPending = queue.isNotEmpty;

        final baseIcon = Icon(
          Icons.checklist_rounded,
          // Let NavigationBar handle overall color; don’t override unless you want special selected styling.
          color: selected ? cs.onSecondaryContainer : null,
        );

        if (!hasPending) return baseIcon;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            baseIcon,
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cs.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
