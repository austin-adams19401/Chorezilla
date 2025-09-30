import 'package:flutter/material.dart';
import 'package:chorezilla/components/auth_scaffold.dart';
import 'package:chorezilla/components/inputs.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      headerTitle: 'Welcome back',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sign in',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: cs.secondary, fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: _busy
                  ? const SizedBox(
                      height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: const Text('Sign in'),
              onPressed: _busy ? null : () async {
                if (!_form.currentState!.validate()) return;
                setState(() => _busy = true);

                // TODO: sign in
                await Future.delayed(const Duration(milliseconds: 600));

                if (!mounted) return;
                setState(() => _busy = false);

                final app = context.read<AppState>();
                final needsSetup = app.family == null || app.members.isEmpty;
                Navigator.of(context).pushReplacementNamed(needsSetup ? '/family-setup' : '/home');
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/register');
              },
              child: Text("Don't have an account? Create one",
                  style: TextStyle(color: cs.secondary)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {}, // TODO: forgot password
                child: Text('Forgot password?',
                    style: TextStyle(color: cs.tertiary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
