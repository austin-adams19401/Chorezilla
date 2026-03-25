import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const _difficultyLabels = {
  1: 'Very easy',
  2: 'Easy',
  3: 'Medium',
  4: 'Hard',
  5: 'Epic',
};

class CoinEconomyPage extends StatefulWidget {
  const CoinEconomyPage({super.key});

  @override
  State<CoinEconomyPage> createState() => _CoinEconomyPageState();
}

class _CoinEconomyPageState extends State<CoinEconomyPage> {
  final _xpControllers = <int, TextEditingController>{};
  late final TextEditingController _coinPerPointCtrl;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().family?.settings ?? const FamilySettings();
    for (var d = 1; d <= 5; d++) {
      final xp = settings.difficultyToXP[d] ?? (d * 10);
      _xpControllers[d] = TextEditingController(text: xp.toString());
    }
    _coinPerPointCtrl = TextEditingController(
      text: settings.coinPerPoint.toString(),
    );

    for (final ctrl in _xpControllers.values) {
      ctrl.addListener(_rebuild);
    }
    _coinPerPointCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    for (final ctrl in _xpControllers.values) {
      ctrl.dispose();
    }
    _coinPerPointCtrl.dispose();
    super.dispose();
  }

  int? _xp(int difficulty) => int.tryParse(_xpControllers[difficulty]!.text);
  double? get _coinPerPoint => double.tryParse(_coinPerPointCtrl.text);

  int? _coins(int difficulty) {
    final xp = _xp(difficulty);
    final cpp = _coinPerPoint;
    if (xp == null || cpp == null) return null;
    return (xp * cpp).round();
  }

  bool get _valid {
    if (_coinPerPoint == null || _coinPerPoint! <= 0) return false;
    for (var d = 1; d <= 5; d++) {
      final xp = _xp(d);
      if (xp == null || xp <= 0) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_valid) return;
    final app = context.read<AppState>();
    final famId = app.familyId;
    if (famId == null) return;

    final newSettings = FamilySettings(
      difficultyToXP: {for (var d = 1; d <= 5; d++) d: _xp(d)!},
      coinPerPoint: _coinPerPoint!,
      dayStartHour: app.family?.settings.dayStartHour ?? 0,
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.repo.updateFamily(famId, {'settings': newSettings.toMap()});
      await app.repo.recalculateChoreAwards(famId, newSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coin economy saved')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coin economy'),
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'XP per difficulty',
            style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Set how many XP points each difficulty level awards. Coins are calculated from XP using the multiplier below.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (var d = 1; d <= 5; d++) _DifficultyRow(
            difficulty: d,
            label: _difficultyLabels[d]!,
            controller: _xpControllers[d]!,
            coins: _coins(d),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Coin multiplier',
            style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'How many coins per XP point. e.g. 0.1 means 10 XP = 1 coin.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _coinPerPointCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              labelText: 'Coins per XP',
              hintText: '0.1',
              border: const OutlineInputBorder(),
              errorText: _coinPerPoint != null && _coinPerPoint! <= 0
                  ? 'Must be greater than 0'
                  : null,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_busy || !_valid) ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({
    required this.difficulty,
    required this.label,
    required this.controller,
    required this.coins,
  });

  final int difficulty;
  final String label;
  final TextEditingController controller;
  final int? coins;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final xp = int.tryParse(controller.text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: label,
                suffixText: 'XP',
                border: const OutlineInputBorder(),
                errorText: xp != null && xp <= 0 ? 'Must be > 0' : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    coins != null ? '$coins' : '--',
                    style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
