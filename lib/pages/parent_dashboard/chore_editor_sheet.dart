import 'package:chorezilla/constants/default_chores.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/recurrance.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChoreEditorSheet extends StatefulWidget {
  const ChoreEditorSheet({super.key, required this.family, this.chore});
  final Family family;
  final Chore? chore;

  @override
  State<ChoreEditorSheet> createState() => _ChoreEditorSheetState();
}

class _ChoreEditorSheetState extends State<ChoreEditorSheet> {
  final _title = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _desc = TextEditingController();
  final _icon = TextEditingController(text: '🧹');
  final int kMaxChoreTitleLength = 30;
  int _difficulty = 3;
  String _recType = 'daily'; // once | daily | weekly | custom
  final Set<int> _days = {}; // 1..7
  String? _timeOfDay;
  bool _busy = false;
  bool _requiresApproval = false;
  bool _bonusOnly = false;

  @override
  void initState() {
    super.initState();
    final c = widget.chore;
    if (c != null) {
      _title.text = c.title;
      _desc.text = c.description ?? '';
      _icon.text = c.icon ?? '🧹';
      _difficulty = c.difficulty;
      _recType = c.recurrence?.type ?? 'once';
      _days
        ..clear()
        ..addAll(c.recurrence?.daysOfWeek ?? const []);
      _timeOfDay = c.recurrence?.timeOfDay;
      _requiresApproval = c.requiresApproval;
      _bonusOnly = c.bonusOnly;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocusNode.dispose();
    _desc.dispose();
    _icon.dispose();
    super.dispose();
  }

  int get _xp => _difficulty == 0
      ? 0
      : widget.family.settings.difficultyToXP[_difficulty] ?? _difficulty * 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final cs = theme.colorScheme;
    final isEdit = widget.chore != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add_task_rounded,
                            color: cs.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit chore' : 'New chore',
                            style: ts.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.help_outline_rounded),
                          tooltip: 'How chores work',
                          onPressed: () => _showChoreHelpDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Title & Description ──────────────────────────────
                    RawAutocomplete<DefaultChore>(
                      textEditingController: _title,
                      focusNode: _titleFocusNode,
                      displayStringForOption: (option) => option.title,
                      optionsBuilder: (textEditingValue) {
                        final input = textEditingValue.text.toLowerCase();
                        if (input.length < 2) return const Iterable.empty();
                        final existingTitles = context
                            .read<AppState>()
                            .chores
                            .map((c) => c.title.toLowerCase())
                            .toSet();
                        return kDefaultChores.where(
                          (c) =>
                              c.title.toLowerCase().contains(input) &&
                              !existingTitles.contains(c.title.toLowerCase()),
                        );
                      },
                      onSelected: (DefaultChore chore) {
                        _title.text = chore.title;
                        _desc.text = chore.description;
                        _icon.text = chore.icon;
                        setState(() {});
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLength: kMaxChoreTitleLength,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            helperText: 'max 30 characters',
                          ),
                          onSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        final cs = Theme.of(context).colorScheme;
                        final ts = Theme.of(context).textTheme;
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            color: cs.surface,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            option.icon,
                                            style: const TextStyle(fontSize: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            option.title,
                                            style: ts.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _desc,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Icon + Difficulty ────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _openEmojiPicker,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _icon,
                                    builder: (_, val, _) => Text(
                                      val.text.isEmpty ? '🧹' : val.text,
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to change',
                                  style: ts.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<int>(
                                initialValue: _difficulty,
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('Reminder')),
                                  DropdownMenuItem(value: 1, child: Text('Very easy')),
                                  DropdownMenuItem(value: 2, child: Text('Easy')),
                                  DropdownMenuItem(value: 3, child: Text('Medium')),
                                  DropdownMenuItem(value: 4, child: Text('Hard')),
                                  DropdownMenuItem(value: 5, child: Text('Epic')),
                                ],
                                onChanged: (v) => setState(() => _difficulty = v ?? 2),
                                decoration: const InputDecoration(
                                  labelText: 'Difficulty',
                                ),
                              ),
                              const SizedBox(height: 8),
                              _XpBadge(xp: _xp, isReminder: _difficulty == 0),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Options section ──────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'OPTIONS',
                          style: ts.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: const Text('Requires parent approval'),
                            subtitle: const Text(
                              'Chore will need to be checked by a parent before it\'s marked complete.',
                            ),
                            value: _requiresApproval,
                            onChanged: (v) =>
                                setState(() => _requiresApproval = v),
                          ),
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: cs.outlineVariant,
                          ),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: const Text('Bonus / extra chore'),
                            subtitle: const Text(
                              'Kids can pick this up for extra XP and coins.',
                            ),
                            value: _bonusOnly,
                            onChanged: (v) => setState(() => _bonusOnly = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Save / Cancel ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(isEdit ? 'Update chore' : 'Create chore'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEmojiPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _EmojiPicker(),
    );
    if (picked != null && mounted) {
      setState(() => _icon.text = picked);
    }
  }

  Future<void> _save() async {
    final rawTitle = _title.text.trim();
    if (rawTitle.isEmpty) return;

    final title = rawTitle.length > kMaxChoreTitleLength
        ? rawTitle.substring(0, kMaxChoreTitleLength)
        : rawTitle;

    setState(() => _busy = true);
    try {
      final app = context.read<AppState>();
      final rec = Recurrence(
        type: _recType,
        daysOfWeek: (_recType == 'weekly' || _recType == 'custom')
            ? _days.toList()
            : null,
        timeOfDay: _timeOfDay,
      );
      if (widget.chore == null) {
        await app.createChore(
          title: title,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          iconKey: _icon.text,
          difficulty: _difficulty,
          recurrence: rec,
          requiresApproval: _requiresApproval,
          bonusOnly: _bonusOnly,
        );
      } else {
        await app.updateChore(
          choreId: widget.chore!.id,
          title: title,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          iconKey: _icon.text,
          difficulty: _difficulty,
          recurrence: rec,
          requiresApproval: _requiresApproval,
          bonusOnly: _bonusOnly,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showChoreHelpDialog(BuildContext context) {
    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final cs = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chore details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is where you define what a chore is and how it works.',
              style: ts.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '• Title & description are what kids see in their list.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Icon (emoji) helps kids quickly recognize the chore.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Difficulty controls how many XP points the chore is worth.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• "Requires parent approval" sends completed chores to the Approve tab before coins/XP are awarded.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Recurrence (once/daily/weekly/custom) and days of the week describe how often the chore should be done.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Time is optional and mainly a reference for when you expect the chore to be finished.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp, required this.isReminder});
  final int xp;
  final bool isReminder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReminder ? Icons.notifications_outlined : Icons.bolt_rounded,
            size: 14,
            color: cs.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            isReminder ? 'No XP (reminder)' : '$xp XP',
            style: ts.labelMedium?.copyWith(
              color: cs.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker();

  static const _emojis = [
    // Cleaning
    '🧹', '🧽', '🧼', '🫧', '🪣', '🧻', '🪥', '🪠',
    // Laundry
    '🧺', '👕', '🧦', '🧴',
    // Bathroom
    '🚿', '🛁', '🚽',
    // Kitchen
    '🍽️', '🍳', '🥄', '🍴', '🥘', '🫙', '🧊', '🧃', '🗑️', '♻️',
    // Bedroom & home
    '🛏️', '🪑', '🛋️', '🪴', '🪞', '🪟', '🚪', '🏠',
    // Yard & garden
    '🌿', '🌱', '🌾', '🍂', '🌻', '🌲',
    // Pets
    '🐶', '🐱', '🐠', '🐹',
    // School & learning
    '📚', '🎒', '✏️', '📝',
    // Getting ready
    '🪮', '🧤', '🧢', '👟',
    // Errands & misc
    '🚗', '🛒', '📦', '🔧', '💡', '⭐', '🏆', '🧩',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose an icon',
                style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: SizedBox(
              height: 380,
              child: GridView.builder(
                itemCount: _emojis.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (_, i) {
                  final e = _emojis[i];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(e),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
