import 'package:chorezilla/components/pin_pad.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';

class ParentPinSetupPage extends StatefulWidget {
  const ParentPinSetupPage({super.key});

  @override
  State<ParentPinSetupPage> createState() => _ParentPinSetupPageState();
}

class _ParentPinSetupPageState extends State<ParentPinSetupPage> {
  String _pin = '';
  String _confirm = '';
  int _active = 0;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_pin.length != 4) {
      setState(() => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    if (_pin != _confirm) {
      setState(() => _error = 'PINs don\u2019t match.');
      return;
    }

    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.updateParentPin(pin: _pin);
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
    Navigator.of(context).pop(true);
  }

  void _onDigit(String next) {
    setState(() {
      _error = null;
      if (_active == 0) {
        _pin = next;
        if (_pin.length == 4) _active = 1;
      } else {
        _confirm = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final hasExistingPin = context.watch<AppState>().hasParentPin;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Parent PIN'),
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 12 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 24),
                      Text('Parent PIN', style: ts.labelLarge),
                      const SizedBox(height: 8),
                      PinDots(
                        value: _pin,
                        length: 4,
                        selected: _active == 0,
                        onTap: () => setState(() => _active = 0),
                      ),
                      const SizedBox(height: 16),
                      Text('Confirm PIN', style: ts.labelLarge),
                      const SizedBox(height: 8),
                      PinDots(
                        value: _confirm,
                        length: 4,
                        selected: _active == 1,
                        onTap: () => setState(() => _active = 1),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: ts.bodySmall?.copyWith(color: cs.error)),
                      ],
                      const SizedBox(height: 16),
                      PinPad(
                        value: _active == 0 ? _pin : _confirm,
                        onChanged: _onDigit,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : Text(
                            hasExistingPin ? 'Save PIN' : 'Save & continue',
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
