import 'package:chorezilla/components/pin_pad.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shows a parent PIN dialog as a parental gate.
/// Returns `true` if PIN verified, `false` if cancelled or failed.
///
/// If no parent PIN is set, returns `true` immediately.
Future<bool> showParentPinGate(BuildContext context) async {
  final app = context.read<AppState>();

  if (!app.hasParentPin) return true;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ParentPinGateDialog(),
  );

  return ok == true;
}

class _ParentPinGateDialog extends StatefulWidget {
  const _ParentPinGateDialog();

  @override
  State<_ParentPinGateDialog> createState() => _ParentPinGateDialogState();
}

class _ParentPinGateDialogState extends State<_ParentPinGateDialog> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    final app = context.read<AppState>();
    if (_pin.length != 4) {
      setState(() => _error = 'Enter your 4-digit parent PIN.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    bool ok;
    try {
      ok = await app.verifyParentPin(_pin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      setState(() => _error = "Wrong PIN. Are you sure you're a parent? 🤔");
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: cs.primaryContainer,
            child: Icon(
              Icons.lock_outline_rounded,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Parents only',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Enter your parent PIN to continue.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          PinDots(value: _pin, length: 4, selected: true),
          const SizedBox(height: 12),
          PinPad(
            value: _pin,
            onChanged: (next) => setState(() {
              _pin = next;
              _error = null;
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ],
        ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
