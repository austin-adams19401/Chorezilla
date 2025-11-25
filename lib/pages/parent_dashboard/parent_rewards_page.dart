// import 'package:chorezilla/models/common.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import 'package:chorezilla/state/app_state.dart';
// import 'package:chorezilla/models/member.dart';
// import 'package:chorezilla/models/reward.dart';
// import 'package:chorezilla/models/reward_redemption.dart';

// class ParentRewardsTab extends StatefulWidget {
//   const ParentRewardsTab({super.key});

//   @override
//   State<ParentRewardsTab> createState() => _ParentRewardsTabState();
// }

// class _ParentRewardsTabState extends State<ParentRewardsTab> {
//   String? _selectedKidId;

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final theme = Theme.of(context);
//     final cs = theme.colorScheme;

//     // You already have members in AppState
//     final kids = app.members.where((m) => m.role == FamilyRole.child && m.active).toList();
//     if (kids.isEmpty) {
//       return const Center(child: Text('Add kids to start using rewards.'));
//     }

//     final selectedKid = kids.firstWhere(
//       (m) => m.id == _selectedKidId,
//       orElse: () => kids.first,
//     );
//     _selectedKidId ??= selectedKid.id;

//     // TODO: wire these up to your actual notifiers/streams
//     final coinBalance = app.coinBalanceForMember(selectedKid.id); // int
//     final allowance = app.allowanceForMember(
//       selectedKid.id,
//     ); // AllowanceSettings?
//     final pending = app.pendingRewardsForMember(
//       selectedKid.id,
//     ); // List<RewardRedemption>
//     final allRewards = app.rewards; // List<RewardDefinition>

//     final activeRewards = allRewards.where((r) => r.active).toList()
//       ..sort((a, b) => a.coinCost.compareTo(b.coinCost));

//     final rewardsByCost = <int, List<RewardDefinition>>{};
//     for (final r in activeRewards) {
//       rewardsByCost.putIfAbsent(r.coinCost, () => []).add(r);
//     }

//     return SafeArea(
//       child: CustomScrollView(
//         slivers: [
//           // Kid selector
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//               child: Row(
//                 children: [
//                   Text(
//                     'Rewards',
//                     style: theme.textTheme.titleLarge?.copyWith(
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                   const Spacer(),
//                   Wrap(
//                     spacing: 8,
//                     children: kids.map((k) {
//                       final selected = k.id == _selectedKidId;
//                       return ChoiceChip(
//                         label: Text(k.displayName),
//                         selected: selected,
//                         onSelected: (_) =>
//                             setState(() => _selectedKidId = k.id),
//                       );
//                     }).toList(),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // Balance + allowance card
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
//               child: Card(
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                   side: BorderSide(color: cs.outlineVariant),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         selectedKid.displayName,
//                         style: theme.textTheme.titleMedium?.copyWith(
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Icon(Icons.savings_rounded, color: cs.primary),
//                           const SizedBox(width: 8),
//                           Text(
//                             '$coinBalance coins',
//                             style: theme.textTheme.titleLarge?.copyWith(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                       if (allowance != null && allowance.enabled) ...[
//                         const SizedBox(height: 12),
//                         Row(
//                           children: [
//                             Icon(Icons.payments_rounded, color: cs.secondary),
//                             const SizedBox(width: 8),
//                             Text(
//                               'Weekly allowance: \$${(allowance.amountCents / 100).toStringAsFixed(0)}',
//                               style: theme.textTheme.bodyMedium,
//                             ),
//                           ],
//                         ),
//                         // Later we can show real progress based on streaks/history
//                         const SizedBox(height: 4),
//                         Text(
//                           'Earned by keeping a perfect week of chores.',
//                           style: theme.textTheme.bodySmall?.copyWith(
//                             color: cs.onSurfaceVariant,
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           // Pending redemptions
//           if (pending.isNotEmpty)
//             SliverToBoxAdapter(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
//                 child: Text(
//                   'Pending rewards to give',
//                   style: theme.textTheme.labelLarge?.copyWith(
//                     color: cs.onSurfaceVariant,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//           if (pending.isNotEmpty)
//             SliverList(
//               delegate: SliverChildBuilderDelegate((ctx, index) {
//                 final red = pending[index];
//                 final reward = activeRewards.firstWhere(
//                   (r) => r.id == red.rewardId,
//                   orElse: () => activeRewards.first,
//                 );

//                 return Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
//                   child: Card(
//                     elevation: 0,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14),
//                       side: BorderSide(color: cs.primary),
//                     ),
//                     child: ListTile(
//                       leading: Text(
//                         reward.icon ?? '🎁',
//                         style: const TextStyle(fontSize: 28),
//                       ),
//                       title: Text(reward.title),
//                       subtitle: Text(
//                         'Requested on ${red.requestedAt.month}/${red.requestedAt.day}',
//                       ),
//                       trailing: FilledButton(
//                         onPressed: () {
//                           app.markRewardFulfilled(red.id);
//                         },
//                         child: const Text('Mark given'),
//                       ),
//                     ),
//                   ),
//                 );
//               }, childCount: pending.length),
//             ),

//           // Shop header
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
//               child: Row(
//                 children: [
//                   Text(
//                     'Reward shop',
//                     style: theme.textTheme.titleMedium?.copyWith(
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const Spacer(),
//                   TextButton.icon(
//                     onPressed: () {
//                       // TODO: open "Manage rewards" screen (enable/disable, custom rewards)
//                     },
//                     icon: const Icon(Icons.settings_outlined, size: 18),
//                     label: const Text('Manage'),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // Shop grouped by coin cost
//           SliverList(
//             delegate: SliverChildBuilderDelegate((ctx, index) {
//               final cost = rewardsByCost.keys.toList()..sort();
//               final coinCost = cost[index];
//               final rewards = rewardsByCost[coinCost]!;

//               return Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       '$coinCost coins',
//                       style: theme.textTheme.labelLarge?.copyWith(
//                         color: cs.onSurfaceVariant,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Wrap(
//                       spacing: 8,
//                       runSpacing: 8,
//                       children: rewards.map((r) {
//                         final canAfford = coinBalance >= r.coinCost;
//                         return _RewardChip(
//                           reward: r,
//                           enabled: canAfford,
//                           onTap: () {
//                             if (!canAfford) return;
//                             app.redeemReward(r, selectedKid.id);
//                           },
//                         );
//                       }).toList(),
//                     ),
//                   ],
//                 ),
//               );
//             }, childCount: rewardsByCost.length),
//           ),
//           const SliverToBoxAdapter(child: SizedBox(height: 24)),
//         ],
//       ),
//     );
//   }
// }

// class _RewardChip extends StatelessWidget {
//   const _RewardChip({
//     required this.reward,
//     required this.enabled,
//     required this.onTap,
//   });

//   final RewardDefinition reward;
//   final bool enabled;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return InkWell(
//       onTap: enabled ? onTap : null,
//       borderRadius: BorderRadius.circular(14),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//         decoration: BoxDecoration(
//           color: enabled
//               ? cs.primaryContainer.withValues(alpha: 0.7)
//               : cs.surfaceContainerHighest,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: enabled ? cs.primary : cs.outlineVariant),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(reward.icon ?? '🎁', style: const TextStyle(fontSize: 20)),
//             const SizedBox(width: 6),
//             Text(
//               reward.title,
//               style: TextStyle(
//                 fontWeight: FontWeight.w600,
//                 color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
