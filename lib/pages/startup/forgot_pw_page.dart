import 'package:chorezilla/components/auth_scaffold.dart';
import 'package:chorezilla/components/inputs.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      if (mounted) setState(() { _sent = true; });
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Something went wrong. Please try again.'; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      headerTitle: 'Forgot Password?',
      headerSubtitle: 'We\'ll send a reset link to your email.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reset password',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: cs.secondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendReset(),
              decoration: themedInput(context, 'Email'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                return ok ? null : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _sendReset,
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
                    : const Text(
                        'Send reset link',
                        key: ValueKey('label'),
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
            if (_sent) ...[
              const SizedBox(height: 12),
              Text(
                'Reset link sent! Check your email.',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Back to sign in',
                style: TextStyle(color: cs.secondary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
