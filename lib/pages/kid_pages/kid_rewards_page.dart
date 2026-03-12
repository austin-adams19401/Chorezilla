// lib/pages/kid_pages/kid_rewards_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/reward.dart';
import 'package:chorezilla/models/reward_redemption.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/cosmetics.dart';
import 'package:chorezilla/components/loot_box_open_dialog.dart';

class KidRewardsPage extends StatefulWidget {
  const KidRewardsPage({super.key, this.memberId, this.initialTabIndex = 0 });

  final String? memberId;  
  final int initialTabIndex;

  @override
  State<KidRewardsPage> createState() => _KidRewardsPageState();
}

class _KidRewardsPageState extends State<KidRewardsPage>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _busyRewardIds = <String>{};

  @override
  void initState() {
    super.initState();

    // Make sure kid streams are running even if we came here first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      final member = _resolveMember(app);
      if (member != null) {
        app.startKidStreams(member.id);
      }
    });
  }

  Member? _resolveMember(AppState app) {
    if (!app.isReady) return null;

    if (widget.memberId != null) {
      try {
        return app.members.firstWhere((m) => m.id == widget.memberId);
      } catch (_) {
        // fall through
      }
    }

    if (app.currentMember != null) {
      return app.currentMember;
    }

    return app.members.isNotEmpty ? app.members.first : null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();

    if (!app.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final member = _resolveMember(app);
    if (member == null) {
      return const Scaffold(body: Center(child: Text('No kid selected')));
    }
    if (member.role != FamilyRole.child) {
      return const Scaffold(
        body: Center(child: Text('Rewards are for child accounts.')),
      );
    }

    final rewards = [...app.rewards]
      ..sort((a, b) => a.coinCost.compareTo(b.coinCost));

    final myRedemptions = app.rewardRedemptionsForKid(member.id);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
        elevation: 0,
        title: Text("Reward Store"),
      ),
      body: Stack(
        children: [
          // background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.secondary, cs.primary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 4),
              _WalletHeader(member: member),
              const SizedBox(height: 8),

              // Store / My Rewards tabs on a rounded sheet
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: const BorderRadius.all(Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: DefaultTabController(
                      length: 3,
                      initialIndex: widget.initialTabIndex.clamp(0, 2),
                      child: Column(
                        children: [
                          TabBar(
                            indicatorColor: cs.secondary,
                            labelColor: cs.secondary,
                            unselectedLabelColor: cs.onSurface,
                            tabs: const [
                              Tab(text: 'Store'),
                              Tab(text: 'My Rewards'),
                              Tab(text: 'Cosmetics'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _RewardStoreTab(
                                  member: member,
                                  rewards: rewards,
                                  busyRewardIds: _busyRewardIds,
                                  onPurchase: _purchaseReward,
                                ),
                                _MyRewardsTab(redemptions: myRedemptions),
                                _CosmeticsTab(member: member),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Future<void> _purchaseReward(Member member, Reward reward) async {
    final app = context.read<AppState>();

    if (member.coins < reward.coinCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins for this reward.')),
      );
      return;
    }

    setState(() => _busyRewardIds.add(reward.id));

    try {
      await app.purchaseReward(member.id, reward);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Requested "${reward.title}"')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not purchase: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyRewardIds.remove(reward.id));
      }
    }
  }

  @override
  bool get wantKeepAlive => true;
}


// ─────────────────────────────────────────────────────────────────────────────
// Wallet header
// ─────────────────────────────────────────────────────────────────────────────

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary,
              cs.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Big faint coin in the corner for some personality
            Positioned(
              right: -4,
              top: -10,
              child: Text(
                '🪙',
                style: TextStyle(
                  fontSize: 48,
                  color: cs.onPrimaryContainer.withValues(alpha: .36),
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + coin balance
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${member.coins} coins to spend',
                                  overflow: TextOverflow.ellipsis,
                                  style: ts.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Store tab
// ─────────────────────────────────────────────────────────────────────────────

class _RewardStoreTab extends StatelessWidget {
  const _RewardStoreTab({
    required this.member,
    required this.rewards,
    required this.busyRewardIds,
    required this.onPurchase,
  });

  final Member member;
  final List<Reward> rewards;
  final Set<String> busyRewardIds;
  final Future<void> Function(Member, Reward) onPurchase;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return const _EmptyStateKidRewards(
        emoji: '🛍️',
        title: 'No rewards yet',
        subtitle:
            'Ask a parent to add some rewards like screen time, desserts, or special privileges.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int crossAxisCount;
        if (width < 480) {
          crossAxisCount = 1; // phones → full-width card rows
        } else if (width < 900) {
          crossAxisCount = 2; // tablets
        } else {
          crossAxisCount = 3; // big screens
        }

        const tileHeight = 160.0;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent:
                tileHeight, 
          ),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final r = rewards[index];
            final canAfford = member.coins >= r.coinCost;
            final soldOut = r.stock != null && r.stock! <= 0;
            final busy = busyRewardIds.contains(r.id);

            return _RewardTile(
              reward: r,
              canAfford: canAfford && !soldOut && !busy,
              soldOut: soldOut,
              busy: busy,
              onPressed: () => onPurchase(member, r),
            );
          },
        );
      },
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.canAfford,
    required this.soldOut,
    required this.busy,
    required this.onPressed,
  });

  final Reward reward;
  final bool canAfford;
  final bool soldOut;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final iconText = (reward.icon?.trim().isNotEmpty ?? false)
        ? reward.icon!.trim()
        : '🎁';

    final subtitleParts = <String>[];
    if (reward.description != null && reward.description!.isNotEmpty) {
      subtitleParts.add(reward.description!);
    }
    if (reward.stock != null) {
      subtitleParts.add('Stock: ${reward.stock}');
    }
    final subtitleText = subtitleParts.join(' • ');

    final bool disabled = !canAfford || soldOut;

    final Color cardColor = soldOut
        ? cs.surfaceContainerHighest
        : disabled
        ? cs.surfaceContainer
        : cs.surface;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(iconText, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ts.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (subtitleText.isNotEmpty)
                    Text(
                      subtitleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('🪙'),
                      const SizedBox(width: 4),
                      Text(
                        '${reward.coinCost} coins',
                        style: ts.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: disabled ? cs.onSurfaceVariant : cs.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (soldOut)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Sold out',
                  style: ts.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              FilledButton(
                onPressed: disabled || busy ? null : onPressed,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buy'),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Rewards tab
// ─────────────────────────────────────────────────────────────────────────────

class _MyRewardsTab extends StatelessWidget {
  const _MyRewardsTab({required this.redemptions});

  final List<RewardRedemption> redemptions;

  @override
  Widget build(BuildContext context) {
    if (redemptions.isEmpty) {
      return const _EmptyStateKidRewards(
        emoji: '✨',
        title: 'No rewards yet',
        subtitle:
            'When you buy rewards or earn allowance, they’ll show up here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: redemptions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final r = redemptions[index];
        return _RedemptionTile(redemption: r);
      },
    );
  }
}

class _RedemptionTile extends StatelessWidget {
  const _RedemptionTile({required this.redemption});

  final RewardRedemption redemption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    // Map status → label + icon
    String statusLabel;
    IconData statusIcon;
    Color statusColor;

    switch (redemption.status) {
      case 'pending':
        statusLabel = 'Waiting for parent';
        statusIcon = Icons.hourglass_bottom_rounded;
        statusColor = cs.secondary;
        break;
      case 'given':
      case 'fulfilled':
        statusLabel = 'Given';
        statusIcon = Icons.check_circle_rounded;
        statusColor = cs.primary;
        break;
      case 'cancelled':
        statusLabel = 'Cancelled';
        statusIcon = Icons.cancel_rounded;
        statusColor = cs.error;
        break;
      default:
        statusLabel = redemption.status;
        statusIcon = Icons.help_outline_rounded;
        statusColor = cs.onSurfaceVariant;
    }

    // Prefer givenAt, fall back to createdAt
    final dt = redemption.givenAt ?? redemption.createdAt;
    String? dateText;
    if (dt != null) {
      final d = DateTime(dt.year, dt.month, dt.day);
      dateText = '${d.month}/${d.day}/${d.year}';
    }

    final subtitleParts = <String>[
      '${redemption.coinCost} coins',
      statusLabel,
      if (dateText != null) dateText,
    ];
    final subtitleText = subtitleParts.join(' • ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          redemption.rewardName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitleText,
          style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Cosmetics tab
// ─────────────────────────────────────────────────────────────────────────────

class _CosmeticsTab extends StatefulWidget {
  const _CosmeticsTab({required this.member});
  final Member member;

  @override
  State<_CosmeticsTab> createState() => _CosmeticsTabState();
}

class _CosmeticsTabState extends State<_CosmeticsTab> {
  final Set<String> _busyIds = {};

  Future<void> _openLootBox(LootBoxDefinition box) async {
    final app = context.read<AppState>();

    if (widget.member.coins < box.costCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins to open this box.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Open ${box.name}?'),
        content: Text(
          'This costs ${box.costCoins} coins and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open it!'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(box.id));
    try {
      final result = await app.openLootBox(widget.member.id, box);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => LootBoxOpenDialog(
          boxDefinition: box,
          result: result,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open box: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(box.id));
    }
  }

  Future<void> _purchaseCosmetic(CosmeticItem item) async {
    final app = context.read<AppState>();

    if (widget.member.coins < item.costCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins.')),
      );
      return;
    }

    setState(() => _busyIds.add(item.id));
    try {
      await app.purchaseCosmetic(widget.member.id, item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Got "${item.name}"!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not buy: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(item.id));
    }
  }

  Future<void> _equipItem(CosmeticItem item) async {
    final app = context.read<AppState>();
    try {
      await app.equipCosmetic(widget.member.id, item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Equipped "${item.name}"!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not equip: $e')),
      );
    }
  }

  String? _equippedIdForType(CosmeticType type) {
    switch (type) {
      case CosmeticType.background:
        return widget.member.equippedBackgroundId;
      case CosmeticType.zillaSkin:
        return widget.member.equippedZillaSkinId;
      case CosmeticType.avatarFrame:
        return widget.member.equippedAvatarFrameId;
      case CosmeticType.title:
        return widget.member.equippedTitleId;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-read member from app state so equipped changes reflect immediately
    final app = context.watch<AppState>();
    final member = app.members.firstWhere(
      (m) => m.id == widget.member.id,
      orElse: () => widget.member,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Loot Boxes ──────────────────────────────────────────────────────
        _SectionHeader(title: 'Loot Boxes', emoji: '🎲'),
        const SizedBox(height: 8),
        Row(
          children: LootBoxCatalog.boxes.map((box) {
            final busy = _busyIds.contains(box.id);
            final canAfford = member.coins >= box.costCoins;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _LootBoxCard(
                  box: box,
                  canAfford: canAfford,
                  busy: busy,
                  onOpen: () => _openLootBox(box),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // ── Backgrounds ──────────────────────────────────────────────────────
        _SectionHeader(title: 'Backgrounds', emoji: '🖼️'),
        const SizedBox(height: 8),
        _CosmeticGrid(
          items: CosmeticCatalog.backgrounds().toList(),
          member: member,
          busyIds: _busyIds,
          getEquippedId: () => _equippedIdForType(CosmeticType.background),
          onBuy: _purchaseCosmetic,
          onEquip: _equipItem,
        ),

        const SizedBox(height: 20),

        // ── Zilla Skins ───────────────────────────────────────────────────────
        _SectionHeader(title: 'Zilla Skins', emoji: '🦖'),
        const SizedBox(height: 8),
        _CosmeticGrid(
          items: CosmeticCatalog.zillaSkins().toList(),
          member: member,
          busyIds: _busyIds,
          getEquippedId: () => _equippedIdForType(CosmeticType.zillaSkin),
          onBuy: _purchaseCosmetic,
          onEquip: _equipItem,
        ),

        const SizedBox(height: 20),

        // ── Avatar Frames ─────────────────────────────────────────────────────
        _SectionHeader(title: 'Avatar Frames', emoji: '⭐'),
        const SizedBox(height: 8),
        _CosmeticGrid(
          items: CosmeticCatalog.avatarFrames().toList(),
          member: member,
          busyIds: _busyIds,
          getEquippedId: () => _equippedIdForType(CosmeticType.avatarFrame),
          onBuy: _purchaseCosmetic,
          onEquip: _equipItem,
        ),

        const SizedBox(height: 20),

        // ── Titles ────────────────────────────────────────────────────────────
        _SectionHeader(title: 'Titles', emoji: '🏆'),
        const SizedBox(height: 8),
        _CosmeticGrid(
          items: CosmeticCatalog.titles().toList(),
          member: member,
          busyIds: _busyIds,
          getEquippedId: () => _equippedIdForType(CosmeticType.title),
          onBuy: _purchaseCosmetic,
          onEquip: _equipItem,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.emoji});
  final String title;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text(
          title,
          style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LootBoxCard extends StatelessWidget {
  const _LootBoxCard({
    required this.box,
    required this.canAfford,
    required this.busy,
    required this.onOpen,
  });

  final LootBoxDefinition box;
  final bool canAfford;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: canAfford ? cs.surface : cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(box.tierEmoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 4),
            Text(
              box.name,
              style: ts.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 2),
                Text(
                  '${box.costCoins}',
                  style: ts.labelSmall?.copyWith(
                    color: canAfford ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canAfford && !busy ? onOpen : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Open'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CosmeticGrid extends StatelessWidget {
  const _CosmeticGrid({
    required this.items,
    required this.member,
    required this.busyIds,
    required this.getEquippedId,
    required this.onBuy,
    required this.onEquip,
  });

  final List<CosmeticItem> items;
  final Member member;
  final Set<String> busyIds;
  final String? Function() getEquippedId;
  final Future<void> Function(CosmeticItem) onBuy;
  final Future<void> Function(CosmeticItem) onEquip;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final owned = item.isDefault || member.ownsCosmetic(item.id);
        final equipped = getEquippedId() == item.id ||
            (item.isDefault && getEquippedId() == null);
        final busy = busyIds.contains(item.id);
        final canAfford = member.coins >= item.costCoins;

        return _CosmeticTile(
          item: item,
          owned: owned,
          equipped: equipped,
          busy: busy,
          canAfford: canAfford,
          onBuy: () => onBuy(item),
          onEquip: () => onEquip(item),
        );
      }).toList(),
    );
  }
}

class _CosmeticTile extends StatelessWidget {
  const _CosmeticTile({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.busy,
    required this.canAfford,
    required this.onBuy,
    required this.onEquip,
  });

  final CosmeticItem item;
  final bool owned;
  final bool equipped;
  final bool busy;
  final bool canAfford;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final String emoji;
    switch (item.type) {
      case CosmeticType.background:
        emoji = '🖼️';
        break;
      case CosmeticType.zillaSkin:
        emoji = '🦖';
        break;
      case CosmeticType.avatarFrame:
        emoji = '⭐';
        break;
      case CosmeticType.title:
        emoji = '🏷️';
        break;
    }

    return Container(
      width: 130,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: equipped
            ? cs.primaryContainer
            : owned
            ? cs.secondaryContainer
            : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: equipped
            ? Border.all(color: cs.primary, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const Spacer(),
              if (equipped)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'On',
                    style: ts.labelSmall?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: ts.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.description.isNotEmpty)
            Text(
              item.description,
              style: ts.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          if (!owned) ...[
            Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 2),
                Text(
                  '${item.costCoins}',
                  style: ts.labelSmall?.copyWith(
                    color: canAfford ? cs.primary : cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canAfford && !busy ? onBuy : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  textStyle: const TextStyle(fontSize: 11),
                  minimumSize: const Size(0, 28),
                ),
                child: busy
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buy'),
              ),
            ),
          ] else if (!equipped) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onEquip,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  textStyle: const TextStyle(fontSize: 11),
                  minimumSize: const Size(0, 28),
                ),
                child: const Text('Equip'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStateKidRewards extends StatelessWidget {
  const _EmptyStateKidRewards({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text(title, style: ts.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}