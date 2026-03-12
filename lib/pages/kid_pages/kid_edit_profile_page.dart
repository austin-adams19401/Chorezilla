import 'package:chorezilla/models/common.dart';
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

  static const _defaultAvatar = '🦖';

  static const List<String> _avatarChoices = [
    '🦖',
    '🦄',
    '🐱',
    '🐶',
    '🐵',
    '🐼',
    '🦊',
    '🐯',
    '🐸',
    '🐨',
    '🐰',
    '🐮',
    '🐹',
    '🐻',
    '🐷',
    '🐭',
    '🦁',
    '🐔',
    '🐥',
    '🦉',
    '🦋',
    '🐞',
    '🐙',
    '🐳',
    '🚀',
    '⚽',
    '🎮',
    '🎲',
    '🎸',
    '🎯',
    '🌈',
    '🍕',
    '🍩',
    '🍪',
    '🍎',
    '🧩',
  ];

  @override
  void initState() {
    super.initState();
    // We can't use context.watch in initState, so we lazily init in didChangeDependencies.
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final app = context.read<AppState>();
    final member = app.members.firstWhere(
      (m) => m.id == widget.memberId,
      orElse: () {
        // Fallback dummy; UI will show error if this happens.
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
      _nameController.text = member.displayName;
      _avatarEmoji = member.avatarKey?.isNotEmpty == true
          ? member.avatarKey
          : _defaultAvatar;
      _backgroundId = member.equippedBackgroundId ?? 'bg_default';
      _avatarFrameId = member.equippedAvatarFrameId ?? 'frame_default';
      _zillaSkinId = member.equippedZillaSkinId ?? 'zilla_green_basic';
      _titleId = member.equippedTitleId ?? 'title_none';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please choose a name.')));
      return;
    }

    setState(() => _saving = true);

    try {
      await app.updateMember(widget.memberId, {
        'displayName': name,
        'avatarKey': _avatarEmoji,
        'equippedBackgroundId': _backgroundId,
        'equippedAvatarFrameId': _avatarFrameId,
        'equippedZillaSkinId': _zillaSkinId,
        'equippedTitleId': _titleId,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save changes: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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

    final backgrounds = CosmeticCatalog.backgrounds().toList();

    final selectedBgId =
        _backgroundId ?? member.equippedBackgroundId ?? 'bg_default';

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${member.displayName}\'s profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big avatar preview
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _avatarEmoji ?? _defaultAvatar,
                    style: const TextStyle(fontSize: 52),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Tap an avatar below to change it',
                style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),

            // Avatar choices
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _avatarChoices.map((emoji) {
                final selected = emoji == _avatarEmoji;
                return GestureDetector(
                  onTap: () {
                    setState(() => _avatarEmoji = emoji);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? cs.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            Text(
              'Background',
              style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick the wallpaper for your chores screen.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: backgrounds.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = backgrounds[index];
                  final selected = item.id == selectedBgId;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _backgroundId = item.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? cs.primary : Colors.transparent,
                          width: 2,
                        ),
                        color: cs.surfaceContainerHighest,
                        image: item.type == CosmeticType.background &&
                                item.assetKey.isNotEmpty
                            ? DecorationImage(
                                image: AssetImage(item.assetKey),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          // Gradient overlay for text readability, if desired
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: .35),
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
                              ),
                            ),
                          ),
                          if (selected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                radius: 12,
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
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── Avatar Frame ────────────────────────────────────────────────
            _EditSectionHeader(
              title: 'Avatar Frame',
              onGetMore: () => _goToCosmetics(context, member.id),
            ),
            const SizedBox(height: 12),
            _buildFramePicker(context, member, cs),

            const SizedBox(height: 24),

            // ── Zilla Skin ──────────────────────────────────────────────────
            _EditSectionHeader(
              title: 'Zilla Skin',
              onGetMore: () => _goToCosmetics(context, member.id),
            ),
            const SizedBox(height: 12),
            _buildSkinPicker(context, member, cs, ts),

            const SizedBox(height: 24),

            // ── Title ────────────────────────────────────────────────────────
            _EditSectionHeader(
              title: 'Title',
              onGetMore: () => _goToCosmetics(context, member.id),
            ),
            const SizedBox(height: 12),
            _buildTitlePicker(context, member, cs, ts),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _goToCosmetics(BuildContext context, String memberId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KidRewardsPage(memberId: memberId, initialTabIndex: 2),
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
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: owned.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final frame = owned[index];
          final isSelected = frame.id == selected;
          return GestureDetector(
            onTap: () => setState(() => _avatarFrameId = frame.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? cs.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text(
                    frame.name,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSkinPicker(BuildContext context, Member member,
      ColorScheme cs, TextTheme ts) {
    final owned = CosmeticCatalog.zillaSkins()
        .where((s) => s.isDefault || member.ownsCosmetic(s.id))
        .toList();

    if (owned.length <= 1) {
      return _EmptyCosmetics(label: 'Zilla skins');
    }

    final selected = _zillaSkinId ?? 'zilla_green_basic';
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: owned.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final skin = owned[index];
          final isSelected = skin.id == selected;
          return GestureDetector(
            onTap: () => setState(() => _zillaSkinId = skin.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? cs.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🦖', style: TextStyle(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text(
                    skin.name,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
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

  Widget _buildTitlePicker(BuildContext context, Member member,
      ColorScheme cs, TextTheme ts) {
    final owned = CosmeticCatalog.titles()
        .where((t) => t.isDefault || member.ownsCosmetic(t.id))
        .toList();

    if (owned.length <= 1) {
      return _EmptyCosmetics(label: 'titles');
    }

    final selected = _titleId ?? 'title_none';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: owned.map((title) {
        final isSelected = title.id == selected;
        return ChoiceChip(
          label: Text(title.name),
          selected: isSelected,
          onSelected: (_) => setState(() => _titleId = title.id),
          selectedColor: cs.primaryContainer,
        );
      }).toList(),
    );
  }
}

class _EditSectionHeader extends StatelessWidget {
  const _EditSectionHeader({required this.title, required this.onGetMore});
  final String title;
  final VoidCallback onGetMore;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        TextButton(
          onPressed: onGetMore,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            foregroundColor: cs.primary,
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('Get more'),
        ),
      ],
    );
  }
}

class _EmptyCosmetics extends StatelessWidget {
  const _EmptyCosmetics({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      'You don\'t own any $label yet — visit the store!',
      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}
