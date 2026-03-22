import 'package:chorezilla/components/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';

class ParentPinSetupPage extends StatefulWidget {
  const ParentPinSetupPage({super.key});

  @override
  State<ParentPinSetupPage> createState() => _ParentPinSetupPageState();
}

class _ParentPinSetupPageState extends State<ParentPinSetupPage> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _confirmFocus = FocusNode();
  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length != 4) {
      setState(() => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs don\u2019t match.');
      return;
    }

    final app = context.read<AppState>();
    setState(() { _busy = true; _error = null; });
    await app.updateParentPin(pin: pin);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final hasExistingPin = context.watch<AppState>().hasParentPin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent PIN'),
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon header ──────────────────────────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: cs.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Create your parent PIN',
                style: ts.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'This 4-digit PIN lets you exit kid mode and unlock any kid\'s profile. Keep it secret from your kids.',
                style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 28),

              // ── PIN field ────────────────────────────────────────────────
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: _obscurePin,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _confirmFocus.requestFocus(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: themedInput(
                  context,
                  'Parent PIN',
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility_off : Icons.visibility,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Confirm field ────────────────────────────────────────────
              TextField(
                controller: _confirmController,
                focusNode: _confirmFocus,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: themedInput(
                  context,
                  'Confirm PIN',
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: ts.bodySmall?.copyWith(color: cs.error)),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: _busy
                        ? SizedBox(
                            key: const ValueKey('spinner'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : Text(
                            hasExistingPin ? 'Save PIN' : 'Save & continue',
                            key: const ValueKey('label'),
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
