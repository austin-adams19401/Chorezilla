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
import 'package:chorezilla/components/avatar_cosmetic_widgets.dart';

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

    final allRedemptions = app.rewardRedemptionsForKid(member.id);
    final boughtRewardIds = allRedemptions
        .where((r) => r.status != 'cancelled' && r.rewardId != null)
        .map((r) => r.rewardId!)
        .toSet();

    final rewards = [...app.rewards]
      ..sort((a, b) => a.coinCost.compareTo(b.coinCost));

    final myRedemptions = allRedemptions
        .where((r) => r.isPending)
        .toList();

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
          Container(color: cs.secondary),

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
                              Tab(text: 'Cosmetics'),
                              Tab(text: 'My Rewards'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _RewardStoreTab(
                                  member: member,
                                  rewards: rewards,
                                  busyRewardIds: _busyRewardIds,
                                  boughtRewardIds: boughtRewardIds,
                                  onPurchase: _purchaseReward,
                                ),
                                _CosmeticsTab(member: member),
                                _MyRewardsTab(redemptions: myRedemptions),
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
    required this.boughtRewardIds,
    required this.onPurchase,
  });

  final Member member;
  final List<Reward> rewards;
  final Set<String> busyRewardIds;
  final Set<String> boughtRewardIds;
  final Future<void> Function(Member, Reward) onPurchase;

  @override
  Widget build(BuildContext context) {
    final visibleRewards = rewards.where((r) => !boughtRewardIds.contains(r.id)).toList();
    if (visibleRewards.isEmpty) {
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
          itemCount: visibleRewards.length,
          itemBuilder: (context, index) {
            final r = visibleRewards[index];
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
        emoji: "\u2728",
        title: "No pending rewards",
        subtitle: "Rewards you buy will show up here while you wait for a parent to give them.",
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
    final member = app.members.firstWhere(
      (m) => m.id == widget.member.id,
      orElse: () => widget.member,
    );

    if (member.coins < box.costCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins to open this box.')),
      );
      return;
    }

    setState(() => _busyIds.add(box.id));
    try {
      // The dialog handles the 3-click mechanic and returns the final result
      final clickState = await showDialog<LootBoxClickState>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LootBoxOpenDialog(
          boxDefinition: box,
          ownedCosmetics: member.ownedCosmetics,
        ),
      );

      if (clickState == null || !mounted) return;

      await app.openLootBox(widget.member.id, box, clickState);
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
      case CosmeticType.avatar:
        return widget.member.avatarKey;
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
        // 2×2 grid of category boxes
        for (int row = 0; row < 2; row++) ...[
          IntrinsicHeight(
           child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: LootBoxCatalog.boxes.skip(row * 2).take(2).map((box) {
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
          ),
          if (row == 0) const SizedBox(height: 8),
        ],

        const SizedBox(height: 12),

        // ── Backgrounds ──────────────────────────────────────────────────────
        _CollapsibleSection(
          title: 'Backgrounds',
          icon: Image.asset('assets/backgrounds/background-icon.png', width: 26, height: 26),
          child: _CosmeticGrid(
            items: CosmeticCatalog.backgrounds().toList(),
            member: member,
            busyIds: _busyIds,
            getEquippedId: () => _equippedIdForType(CosmeticType.background),
            onBuy: _purchaseCosmetic,
          ),
        ),

        // ── Zilla Skins ───────────────────────────────────────────────────────
        _CollapsibleSection(
          title: 'Zilla Skins',
          icon: Image.asset(
            'assets/mascot/mascot_plain.png',
            width: 26,
            height: 26,
          ),
          child: _CosmeticGrid(
            items: CosmeticCatalog.zillaSkins().toList(),
            member: member,
            busyIds: _busyIds,
            getEquippedId: () => _equippedIdForType(CosmeticType.zillaSkin),
            onBuy: _purchaseCosmetic,
          ),
        ),

        // ── Avatar Frames ─────────────────────────────────────────────────────
        _CollapsibleSection(
          title: 'Avatar Frames',
          icon: const Text('⭐', style: TextStyle(fontSize: 22)),
          child: _CosmeticGrid(
            items: CosmeticCatalog.avatarFrames().toList(),
            member: member,
            busyIds: _busyIds,
            getEquippedId: () => _equippedIdForType(CosmeticType.avatarFrame),
            onBuy: _purchaseCosmetic,
          ),
        ),

        // ── Avatars ───────────────────────────────────────────────────────────
        _CollapsibleSection(
          title: 'Avatars',
          icon: Image.asset('assets/avatars/avatar-icon.png', width: 26, height: 26),
          child: _CosmeticGrid(
            items: CosmeticCatalog.avatars().toList(),
            member: member,
            busyIds: _busyIds,
            getEquippedId: () => _equippedIdForType(CosmeticType.avatar),
            onBuy: _purchaseCosmetic,
          ),
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
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text(
          title,
          style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final Widget icon;
  final Widget child;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                widget.icon,
                const SizedBox(width: 6),
                Text(
                  widget.title,
                  style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 4),
          widget.child,
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 4),
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

  static List<Color> _gradientFor(CosmeticType type) {
    switch (type) {
      case CosmeticType.background:
        return [const Color(0xFF0D7377), const Color(0xFF5C35A0)];
      case CosmeticType.zillaSkin:
        return [const Color(0xFF1565C0), const Color(0xFF6A1B9A)];
      case CosmeticType.avatarFrame:
        return [const Color(0xFF7B1FA2), const Color(0xFFC2185B)];
      case CosmeticType.title:
        return [const Color(0xFFE65100), const Color(0xFFB71C1C)];
      case CosmeticType.avatar:
        return [const Color(0xFF00897B), const Color(0xFF00ACC1)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;

    final activeGradient = _gradientFor(box.cosmeticType);
    final glowColor = canAfford ? activeGradient.first : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: activeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // diagonal shine streak
            Positioned(
              top: -24,
              left: -16,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 60,
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (box.cosmeticType == CosmeticType.zillaSkin)
                    Image.asset(
                      'assets/mascot/mascot_plain.png',
                      width: 60,
                      height: 60,
                      color: Colors.white,
                      colorBlendMode: BlendMode.srcIn,
                    )
                  else if (box.cosmeticType == CosmeticType.background)
                    Image.asset(
                      'assets/backgrounds/background-icon.png',
                      width: 60,
                      height: 60,
                    )
                  else if (box.cosmeticType == CosmeticType.avatarFrame)
                    Image.asset(
                      'assets/frames/frame-icon.png',
                      width: 60,
                      height: 60,
                    )
                  else if (box.cosmeticType == CosmeticType.avatar)
                    Image.asset(
                      'assets/avatars/avatar-icon.png',
                      width: 60,
                      height: 60,
                    )
                  else
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Center(
                        child: Text(box.categoryEmoji, style: const TextStyle(fontSize: 46)),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    box.name,
                    style: ts.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 3),
                      Text(
                        '${box.costCoins}',
                        style: ts.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: canAfford && !busy ? onOpen : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: canAfford ? 0.65 : 0.25),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Open'),
                    ),
                  ),
                ],
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
  });

  final List<CosmeticItem> items;
  final Member member;
  final Set<String> busyIds;
  final String? Function() getEquippedId;
  final Future<void> Function(CosmeticItem) onBuy;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((i) => !i.isDefault).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 260 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 160,
          ),
          itemCount: visibleItems.length,
          itemBuilder: (context, index) {
            final item = visibleItems[index];
            final owned = member.ownsCosmetic(item.id);
            final equipped = getEquippedId() == item.id;
            final busy = busyIds.contains(item.id);
            final canAfford = member.coins >= item.costCoins;

            return _CosmeticTile(
              item: item,
              owned: owned,
              equipped: equipped,
              busy: busy,
              canAfford: canAfford,
              onBuy: () => onBuy(item),
            );
          },
        );
      },
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
  });

  final CosmeticItem item;
  final bool owned;
  final bool equipped;
  final bool busy;
  final bool canAfford;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case CosmeticType.background:
        return _buildBackgroundTile(context);
      case CosmeticType.zillaSkin:
        return _buildZillaSkinTile(context);
      case CosmeticType.avatarFrame:
        return _buildAvatarFrameTile(context);
      case CosmeticType.avatar:
        return _buildAvatarTile(context);
      default:
        return _buildGenericTile(context);
    }
  }

  // ── Generic tile (titles, fallback) ───────────────────────────────────────
  Widget _buildGenericTile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: equipped
            ? cs.primaryContainer
            : owned
            ? cs.secondaryContainer
            : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: equipped ? Border.all(color: cs.primary, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏷️', style: TextStyle(fontSize: 20)),
              const Spacer(),
              if (equipped) _equippedBadge(context),
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
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          if (!owned) ...[
            _coinRow(context),
            const SizedBox(height: 4),
            _buyButton(context, fullWidth: true),
          ],
        ],
      ),
    );
  }

  // ── Zilla Skin tile ────────────────────────────────────────────────────────
  Widget _buildZillaSkinTile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final color = item.colorValue != null ? Color(item.colorValue!) : cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: equipped
            ? cs.primaryContainer
            : owned
            ? cs.secondaryContainer
            : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: equipped ? Border.all(color: cs.primary, width: 2) : null,
      ),
      child: Column(
        children: [
          // Preview area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.25),
                      ),
                    ),
                    Image.asset(
                      'assets/mascot/mascot_plain.png',
                      width: 46,
                      height: 46,
                      color: color,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Info area
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: ts.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (equipped) _equippedBadge(context),
                  ],
                ),
                if (!owned) ...[
                  const SizedBox(height: 4),
                  _coinAndBuyRow(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar Frame tile ──────────────────────────────────────────────────────
  Widget _buildAvatarFrameTile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: equipped
            ? cs.primaryContainer
            : owned
            ? cs.secondaryContainer
            : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: equipped ? Border.all(color: cs.primary, width: 2) : null,
      ),
      child: Column(
        children: [
          // Live frame preview
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.primaryContainer,
                    child: const Text('😀', style: TextStyle(fontSize: 22)),
                  ),
                  FrameOverlay(frameId: item.id, radius: 26),
                ],
              ),
            ),
          ),
          // Info area
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: ts.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (equipped) _equippedBadge(context),
                  ],
                ),
                if (!owned) ...[
                  const SizedBox(height: 4),
                  _coinAndBuyRow(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar tile ────────────────────────────────────────────────────────────
  Widget _buildAvatarTile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: equipped ? Border.all(color: cs.primary, width: 2) : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: item.assetKey.isNotEmpty
                  ? Image.asset(item.assetKey, fit: BoxFit.contain, width: double.infinity)
                  : const SizedBox(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: ts.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (equipped) _equippedBadge(context),
                  ],
                ),
                if (item.rarity != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.rarity!.displayName,
                    style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (owned && !equipped) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Owned',
                    style: ts.labelSmall?.copyWith(color: cs.secondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _equippedBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'On',
        style: ts.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _coinRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Row(
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
    );
  }

  Widget _buyButton(BuildContext context, {bool fullWidth = false}) {
    final child = busy
        ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
        : const Text('Buy');
    final button = FilledButton(
      onPressed: canAfford && !busy ? onBuy : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        textStyle: const TextStyle(fontSize: 11),
        minimumSize: const Size(0, 26),
      ),
      child: child,
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _coinAndBuyRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Row(
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
        const Spacer(),
        _buyButton(context),
      ],
    );
  }

  Widget _buildBackgroundTile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _BackgroundPreviewDialog(item: item),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.asset(item.assetKey, fit: BoxFit.cover),
            // Gradient overlay for text readability
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.3, 1.0],
                ),
              ),
            ),
            // Equipped border
            if (equipped)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.primary, width: 2.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            // Content overlay
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white70),
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
                  const Spacer(),
                  Text(
                    item.name,
                    style: ts.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!owned) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 2),
                        Text(
                          '${item.costCoins}',
                          style: ts.labelSmall?.copyWith(
                            color: canAfford ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 26,
                          child: FilledButton(
                            onPressed: canAfford && !busy ? onBuy : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              textStyle: const TextStyle(fontSize: 11),
                              minimumSize: const Size(0, 26),
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Buy'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundPreviewDialog extends StatelessWidget {
  const _BackgroundPreviewDialog({required this.item});

  final CosmeticItem item;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          // Background image
          AspectRatio(
            aspectRatio: 9 / 16,
            child: Image.asset(item.assetKey, fit: BoxFit.cover),
          ),
          // Mascot centered
          Positioned.fill(
            child: Center(
              child: Image.asset(
                'assets/mascot/mascot_plain.png',
                width: 110,
              ),
            ),
          ),
          // Bottom info bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD000000)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: ts.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.rarity != null)
                    Text(
                      item.rarity!.displayName.toUpperCase(),
                      style: ts.labelSmall?.copyWith(
                        color: _rarityColor(item.rarity!),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: ts.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                iconSize: 18,
                minimumSize: const Size(32, 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _rarityColor(CosmeticRarity rarity) {
    switch (rarity) {
      case CosmeticRarity.common:
        return Colors.white70;
      case CosmeticRarity.rare:
        return Colors.lightBlueAccent;
      case CosmeticRarity.epic:
        return Colors.purpleAccent;
    }
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