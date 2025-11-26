import 'package:chorezilla/models/reward_redemption.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/data/chorezilla_repo.dart'; // for RewardRedemption + repo

class RewardsNavIcon extends StatelessWidget {
  const RewardsNavIcon({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final familyId = app.familyId;

    // If no family yet, just show the base icon.
    if (familyId == null) {
      return Icon(
        Icons.card_giftcard_rounded,
        color: selected ? cs.onSecondaryContainer : null,
      );
    }

    return StreamBuilder<List<RewardRedemption>>(
      stream: app.repo.watchPendingRewardRedemptions(familyId),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;

        final baseIcon = Icon(
          Icons.card_giftcard_rounded,
          color: selected ? cs.onSecondaryContainer : null,
        );

        if (count == 0) return baseIcon;

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
