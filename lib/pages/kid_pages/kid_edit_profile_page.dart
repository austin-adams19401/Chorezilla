import 'dart:async';

import 'package:chorezilla/components/avatar_cosmetic_widgets.dart';
import 'package:chorezilla/components/inputs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/cosmetics.dart';
import 'package:chorezilla/pages/kid_pages/kid_rewards_page.dart';

class KidEditProfilePage extends StatefulWidget {
  const KidEditProfilePage({super.key, required this.memberId});

  final String memberId;

  @override
  State<KidEditProfilePage> createState() => _KidEditProfilePageState();
}

class _KidEditProfilePageState extends State<KidEditProfilePage> {
  late TextEditingController _nameController;
  String? _avatarEmoji;
  String? _backgroundId;
  String? _avatarFrameId;
  String? _zillaSkinId;
  String? _titleId;

  bool _saving = false;
  _SaveStatus _saveStatus = _SaveStatus.idle;
  Timer? _nameDebounce;
  Timer? _savedFadeTimer;

  static const _defaultAvatar = 'avatar_default_1';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 800), _autoSave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final app = context.read<AppState>();
    final member = app.members.firstWhere(
      (m) => m.id == widget.memberId,
      orElse: () {
        return app.currentMember ??
            Member(
              id: widget.memberId,
              displayName: 'Kid',
              role: app.members.first.role,
            );
      },
    );

    // Only initialize once
    if (_avatarEmoji == null &&
        _backgroundId == null &&
        _nameController.text.isEmpty) {
      _nameController.text = member.nickname ?? member.displayName;
      final key = member.avatarKey;
      _avatarEmoji = (key != null && key.startsWith('avatar_')) ? key : _defaultAvatar;
      _backgroundId = member.equippedBackgroundId ?? 'bg_default';
      _avatarFrameId = member.equippedAvatarFrameId ?? 'frame_default';
      _zillaSkinId = member.equippedZillaSkinId ?? 'zilla_green_basic';
      _titleId = member.equippedTitleId ?? 'title_none';
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameDebounce?.cancel();
    _savedFadeTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;

    if (mounted) setState(() { _saving = true; _saveStatus = _SaveStatus.saving; });

    try {
      await context.read<AppState>().updateMember(widget.memberId, {
        'nickname': name,
        'avatarKey': _avatarEmoji,
        'equippedBackgroundId': _backgroundId,
        'equippedAvatarFrameId': _avatarFrameId,
        'equippedZillaSkinId': _zillaSkinId,
        'equippedTitleId': _titleId,
      });

      if (!mounted) return;
      setState(() { _saving = false; _saveStatus = _SaveStatus.saved; });
      _savedFadeTimer?.cancel();
      _savedFadeTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saveStatus = _SaveStatus.idle);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saveStatus = _SaveStatus.idle; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  Member _previewMember(Member member) => member.copyWith(
        avatarKey: _avatarEmoji,
        equippedAvatarFrameId: _avatarFrameId,
        equippedZillaSkinId: _zillaSkinId,
        equippedTitleId: _titleId,
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final member = app.members.firstWhere(
      (m) => m.id == widget.memberId,
      orElse: () => app.currentMember ?? app.members.first,
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;
    final ownedBackgrounds = CosmeticCatalog.backgrounds()
        .where((b) => b.isDefault || member.ownsCosmetic(b.id))
        .toList();

    final selectedBgId = _backgroundId ?? member.equippedBackgroundId ?? 'bg_default';
    final selectedBg = ownedBackgrounds.firstWhere(
      (b) => b.id == selectedBgId,
      orElse: () => ownedBackgrounds.first,
    );

    const gradientTop = Color(0xFF0B2545);
    const gradientBottom = Color(0xFF1B8A4C);

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient hero app bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: gradientTop,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'Edit Profile',
              style: ts.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: switch (_saveStatus) {
                    _SaveStatus.saving => const SizedBox(
                        key: ValueKey('saving'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    _SaveStatus.saved => const Row(
                        key: ValueKey('saved'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Color(0xFF2ECC71), size: 18),
                          SizedBox(width: 5),
                          Text('Saved',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    _SaveStatus.idle => const SizedBox.shrink(key: ValueKey('idle')),
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [gradientTop, gradientBottom],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: _PreviewCard(
                          member: _previewMember(member),
                          selectedBg: selectedBg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Scrollable content ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Name
                _SectionCard(
                  color: const Color(0xFF3498DB),
                  icon: Icons.badge_rounded,
                  title: 'Nickname',
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: themedInput(context, 'Nickname'),
                  ),
                ),
                const SizedBox(height: 16),

                // Avatar
                _SectionCard(
                  color: const Color(0xFFE74C3C),
                  icon: Icons.face_rounded,
                  title: 'Avatar',
                  child: _buildAvatarPicker(context, member, cs),
                ),
                const SizedBox(height: 16),

                // Background
                _SectionCard(
                  color: const Color(0xFF9B59B6),
                  icon: Icons.wallpaper_rounded,
                  title: 'Background',
                  trailing: _GetMoreButton(
                    onTap: () => _goToCosmetics(context, member.id),
                  ),
                  child: SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ownedBackgrounds.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = ownedBackgrounds[index];
                        final selected = item.id == selectedBgId;
                        return _BackgroundTile(
                          item: item,
                          selected: selected,
                          cs: cs,
                          ts: ts,
                          onTap: () { setState(() => _backgroundId = item.id); _autoSave(); },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Avatar Frame
                _SectionCard(
                  color: const Color(0xFFF39C12),
                  icon: Icons.crop_free_rounded,
                  title: 'Avatar Frame',
                  trailing: _GetMoreButton(
                    onTap: () => _goToCosmetics(context, member.id),
                  ),
                  child: _buildFramePicker(context, member, cs),
                ),
                const SizedBox(height: 16),

                // Zilla Skin
                _SectionCard(
                  color: const Color(0xFF2ECC71),
                  icon: Icons.color_lens_rounded,
                  title: 'Zilla Skin',
                  trailing: _GetMoreButton(
                    onTap: () => _goToCosmetics(context, member.id),
                  ),
                  child: _buildSkinPicker(context, member, cs, ts),
                ),
                const SizedBox(height: 16),

                // Title
                _SectionCard(
                  color: const Color(0xFF1ABC9C),
                  icon: Icons.military_tech_rounded,
                  title: 'Title',
                  trailing: _GetMoreButton(
                    onTap: () => _goToCosmetics(context, member.id),
                  ),
                  child: _buildTitlePicker(context, member, cs, ts),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _goToCosmetics(BuildContext context, String memberId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KidRewardsPage(memberId: memberId, initialTabIndex: 1),
      ),
    );
  }

  Widget _buildFramePicker(
      BuildContext context, Member member, ColorScheme cs) {
    final owned = CosmeticCatalog.avatarFrames()
        .where((f) => f.isDefault || member.ownsCosmetic(f.id))
        .toList();

    if (owned.length <= 1) {
      return _EmptyCosmetics(label: 'avatar frames');
    }

    final selected = _avatarFrameId ?? 'frame_default';
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: owned.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final frame = owned[index];
          final isSelected = frame.id == selected;
          return GestureDetector(
            onTap: () { setState(() => _avatarFrameId = frame.id); _autoSave(); },
            child: _CosmeticTile(
              isSelected: isSelected,
              cs: cs,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: cs.surfaceContainerHigh,
                      ),
                      FrameOverlay(frameId: frame.id, radius: 20),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    frame.name,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkinPicker(
      BuildContext context, Member member, ColorScheme cs, TextTheme ts) {
    final owned = CosmeticCatalog.zillaSkins()
        .where((s) => s.isDefault || member.ownsCosmetic(s.id))
        .toList();

    if (owned.isEmpty) {
      return _EmptyCosmetics(label: 'Zilla skins');
    }

    final selected = _zillaSkinId ?? 'zilla_green_basic';
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: owned.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final skin = owned[index];
          final isSelected = skin.id == selected;
          return GestureDetector(
            onTap: () { setState(() => _zillaSkinId = skin.id); _autoSave(); },
            child: _CosmeticTile(
              isSelected: isSelected,
              cs: cs,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/mascot/mascot_plain.png',
                    width: 36,
                    height: 36,
                    color: skin.colorValue != null
                        ? Color(skin.colorValue!)
                        : null,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    skin.name,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarPicker(
      BuildContext context, Member member, ColorScheme cs) {
    final defaultImageIds = CosmeticCatalog.avatars()
        .where((a) => a.isDefault)
        .map((a) => a.id)
        .toList();

    final earnedImageIds = CosmeticCatalog.avatars()
        .where((a) => !a.isDefault && member.ownsCosmetic(a.id))
        .map((a) => a.id)
        .toList();

    final allImageIds = [...defaultImageIds, ...earnedImageIds];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: allImageIds.map((id) {
        final item = CosmeticCatalog.byId(id);
        final isSelected = id == _avatarEmoji;
        return GestureDetector(
          onTap: () { setState(() => _avatarEmoji = id); _autoSave(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? cs.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: .35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(item.assetKey, fit: BoxFit.cover),
                  if (isSelected)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: cs.primary,
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTitlePicker(
      BuildContext context, Member member, ColorScheme cs, TextTheme ts) {
    final owned = CosmeticCatalog.titles()
        .where((t) => t.isDefault || member.ownsCosmetic(t.id))
        .toList();

    if (owned.length <= 1) {
      return _EmptyCosmetics(label: 'titles');
    }

    final selected = _titleId ?? 'title_none';

    const chipColors = [
      Color(0xFF3498DB),
      Color(0xFFE74C3C),
      Color(0xFF9B59B6),
      Color(0xFFF39C12),
      Color(0xFF2ECC71),
      Color(0xFF1ABC9C),
      Color(0xFFE67E22),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: owned.asMap().entries.map((entry) {
        final i = entry.key;
        final title = entry.value;
        final isSelected = title.id == selected;
        final chipColor = chipColors[i % chipColors.length];

        return GestureDetector(
          onTap: () { setState(() => _titleId = title.id); _autoSave(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? chipColor
                  : chipColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? chipColor
                    : chipColor.withValues(alpha: .3),
                width: 1.5,
              ),
            ),
            child: Text(
              title.name,
              style: ts.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : chipColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Preview Card ──────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.member, required this.selectedBg});
  final Member member;
  final CosmeticItem selectedBg;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A4B),
                image: selectedBg.assetKey.isNotEmpty
                    ? DecorationImage(
                        image: AssetImage(selectedBg.assetKey),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .5),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWithFrame(member: member, radius: 42),
                const SizedBox(height: 8),
                Text(
                  member.kidName,
                  style: ts.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      const Shadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: .25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: ts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: color.withValues(alpha: .12),
            indent: 14,
            endIndent: 14,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Get More Button ───────────────────────────────────────────────────────────

class _GetMoreButton extends StatelessWidget {
  const _GetMoreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '+ Get more',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Cosmetic Tile ─────────────────────────────────────────────────────────────

class _CosmeticTile extends StatelessWidget {
  const _CosmeticTile({
    required this.isSelected,
    required this.cs,
    required this.child,
  });

  final bool isSelected;
  final ColorScheme cs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 76,
      height: 84,
      decoration: BoxDecoration(
        color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? cs.primary : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: .25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: child,
    );
  }
}

// ── Background Tile ───────────────────────────────────────────────────────────

class _BackgroundTile extends StatelessWidget {
  const _BackgroundTile({
    required this.item,
    required this.selected,
    required this.cs,
    required this.ts,
    required this.onTap,
  });

  final CosmeticItem item;
  final bool selected;
  final ColorScheme cs;
  final TextTheme ts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 3,
          ),
          color: cs.surfaceContainerHighest,
          image: item.assetKey.isNotEmpty
              ? DecorationImage(
                  image: AssetImage(item.assetKey),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: .35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: .5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              right: 10,
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    const Shadow(blurRadius: 3, color: Colors.black87),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: cs.primary,
                  child: const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Empty Cosmetics ───────────────────────────────────────────────────────────

class _EmptyCosmetics extends StatelessWidget {
  const _EmptyCosmetics({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'No $label yet — visit the store!',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

enum _SaveStatus { idle, saving, saved }
