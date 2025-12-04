// lib/pages/onboarding/parent_pin_setup_page.dart
import 'package:flutter/material.dart';
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
  bool _busy = false;
  String? _error;

  bool get _isValid {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    return pin.length == 4 && pin == confirm;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isValid) {
      setState(() {
        _error = 'Enter a 4-digit PIN and make sure both fields match.';
      });
      return;
    }

    final app = context.read<AppState>();
    final pin = _pinController.text.trim();

    setState(() {
      _busy = true;
      _error = null;
    });

    await app.updateParentPin(pin: pin);

    if (!mounted) return;
    setState(() => _busy = false);

    // Pop with success; your onboarding router can wait for this.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // no back button = can't easily skip
        title: const Text('Parent PIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create your parent PIN',
                style: ts.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                "This 4-digit PIN lets you exit kid mode and unlock any kid's profile. "
                "Keep it secret from your kids.",
                style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Parent PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  border: OutlineInputBorder(),
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
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
