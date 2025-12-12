import 'package:chorezilla/models/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/cosmetics.dart';

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
                        image: item.type == CosmeticType.background
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
          ],
        ),
      ),
    );
  }
}
