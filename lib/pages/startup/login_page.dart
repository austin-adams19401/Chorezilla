import 'package:chorezilla/components/auth_scaffold.dart';
import 'package:chorezilla/components/inputs.dart';
import 'package:chorezilla/components/outlined_button.dart';
import 'package:chorezilla/pages/startup/forgot_password_page.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/auth/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; });
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black, fontWeight: FontWeight.w700)
              ),
              const SizedBox(height: 12,),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: themedInput(context, 'Email'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty){
                    return 'Email is required';
                  }
                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                  return ok ? null : 'Enter a valid email';
                },
              ),            
              const SizedBox(height: 12,),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: themedInput(context, 'Password',
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: cs.secondary),
                  onPressed:() => setState(() { _obscure = !_obscure; })
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, 
                          MaterialPageRoute(builder: (context) {
                            return ForgotPasswordPage();
                        }));
                      },
                      child: Text('Forgot Password?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GoogleSignInButton(
                onPressed: () => context.read<AppState>().signInWithGoogle(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/kid-join'),
              style: outlinedButton,
              child: Text(
                'Kid Login (Join with Code)',
                style: TextStyle(fontSize: 16)
              ),
            ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/register');
                },
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: TextStyle(color: cs.inverseSurface,
                          fontSize: 16),),
                      Text("Create one",
                      style: TextStyle(color: cs.secondary, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        ),
      )     
    );
  }
}