import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chorezilla/components/auth_scaffold.dart';
import 'package:chorezilla/components/inputs.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _busy = false;

Future<void> _register() async {
  if (!_form.currentState!.validate()) return;

  setState(() { _busy = true; _error = null; });

  try {
    final userCredentials = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _email.text.trim(),
      password: _password.text,
    );

    final displayName = _name.text.trim();

    await userCredentials.user?.updateDisplayName(displayName);
    if (!mounted) return;

    // 4) Bounce back to root so AuthGate takes over
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);

  } on FirebaseAuthException catch (e) {
    setState(() { _error = e.message ?? 'Registration failed'; });
  } catch (e) {
    setState(() { _error = e.toString(); });
  } finally {
    if (mounted) setState(() { _busy = false; });
  }
}

@override
void dispose() {
  _name.dispose();
  _email.dispose();
  _password.dispose();
  _confirm.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      headerTitle: 'Welcome to Chorezilla',
      headerSubtitle: 'Create your account.\nFamily setup is next.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Register',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: cs.secondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: themedInput(context, 'Your first name'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: themedInput(context, 'Email'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                return ok ? null : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: themedInput(
                context,
                'Password',
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      color: cs.secondary),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'At least 6 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: themedInput(context, 'Confirm password'),
              validator: (v) =>
                  (v != _password.text) ? 'Passwords don’t match' : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _register,
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
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        'Create account',
                        key: ValueKey('label'),
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style: TextStyle(color: cs.secondary, fontSize: 14)),
                  Text('Sign in!', style: TextStyle(color: cs.secondary, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
