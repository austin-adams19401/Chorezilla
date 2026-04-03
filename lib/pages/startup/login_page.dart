import 'dart:io';

import 'package:chorezilla/components/apple_sign_in.dart';
import 'package:chorezilla/components/auth_scaffold.dart';
import 'package:chorezilla/components/inputs.dart';
import 'package:chorezilla/pages/startup/forgot_pw_page.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/components/google_sign_in.dart';
import 'package:chorezilla/services/analytics_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  bool _googleBusy = false;
  String? _googleError;
  bool _appleBusy = false;
  String? _appleError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _googleBusy = true; _googleError = null; });
    try {
      await context.read<AppState>().signInWithGoogle();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _googleError = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Google sign-in failed. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() { _googleBusy = false; });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _appleBusy = true; _appleError = null; });
    try {
      await context.read<AppState>().signInWithApple();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _appleError = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Apple sign-in failed. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() { _appleBusy = false; });
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      AnalyticsService.logLogin();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Incorrect password. Please try again.',
        'user-not-found' => 'No account found with that email.',
        'invalid-email' => 'That doesn\'t look like a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many failed attempts. Please try again later.',
        _ => e.message ?? 'Sign in failed. Please try again.',
      };
      setState(() { _error = msg; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      headerTitle: 'Welcome Back',
      headerSubtitle: 'Let\'s get back to it!',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sign in',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
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
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
                decoration: themedInput(context, 'Password',
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: cs.onSurfaceVariant),
                    onPressed: () => setState(() { _obscure = !_obscure; }),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
                  },
                  child: Text('Forgot Password?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: _busy ? null : _signIn,
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
                          'Sign In',
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
              SizedBox(
                width: double.infinity,
                child: GoogleSignInButton(
                  isLoading: _googleBusy,
                  onPressed: _googleBusy ? null : _signInWithGoogle,
                ),
              ),
              if (_googleError != null) ...[
                const SizedBox(height: 8),
                Text(_googleError!, style: TextStyle(color: cs.error)),
              ],
              if (Platform.isIOS) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: AppleSignInButton(
                    isLoading: _appleBusy,
                    onPressed: _appleBusy ? null : _signInWithApple,
                  ),
                ),
                if (_appleError != null) ...[
                  const SizedBox(height: 8),
                  Text(_appleError!, style: TextStyle(color: cs.error)),
                ],
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/register');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        "Don't have an account? ",
                        style: TextStyle(color: cs.inverseSurface, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Create one',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
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
