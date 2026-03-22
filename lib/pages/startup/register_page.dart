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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;

    setState(() { _busy = true; _error = null; });

    try {
      final userCredentials = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      await userCredentials.user?.updateDisplayName(_name.text.trim());
      if (!mounted) return;

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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      headerTitle: 'Welcome to Chorezilla',
      headerSubtitle: 'Create your account.\nFamily setup is next.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Register',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                decoration: themedInput(context, 'Your first name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
                focusNode: _passwordFocus,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                decoration: themedInput(
                  context,
                  'Password',
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: cs.onSurfaceVariant),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                focusNode: _confirmFocus,
                obscureText: _obscureConfirm,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
                decoration: themedInput(
                  context,
                  'Confirm password',
                  suffix: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: cs.onSurfaceVariant),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) => (v != _password.text) ? 'Passwords don\u2019t match' : null,
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
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Already have an account? ',
                        style: TextStyle(color: cs.inverseSurface, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('Sign in!', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
