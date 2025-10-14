import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'register_page.dart';
import 'parent_join_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
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
      // No nav needed: AuthGate at the app root will rebuild automatically.
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: cs.error)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _busy ? null : () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
                        },
                        child: const Text('Need an account? Register'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentJoinPage()));
                        },
                        child: const Text('Invited parent? Enter your code'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:chorezilla/components/auth_scaffold.dart';
// import 'package:chorezilla/components/inputs.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';


// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});
//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final _form = GlobalKey<FormState>();
//   final _email = TextEditingController();
//   final _password = TextEditingController();
//   bool _obscure = true;
//   final bool _busy = false;

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return AuthScaffold(
//       headerTitle: 'Welcome back',
//       child: Form(
//         key: _form,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Text('Sign in',
//                 style: Theme.of(context)
//                     .textTheme
//                     .titleLarge
//                     ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
//             const SizedBox(height: 12),
//             TextFormField(
//               controller: _email,
//               keyboardType: TextInputType.emailAddress,
//               decoration: themedInput(context, 'Email'),
//               validator: (v) {
//                 if (v == null || v.trim().isEmpty) return 'Email is required';
//                 final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
//                 return ok ? null : 'Enter a valid email';
//               },
//             ),
//             const SizedBox(height: 12),
//             TextFormField(
//               controller: _password,
//               obscureText: _obscure,
//               decoration: themedInput(
//                 context,
//                 'Password',
//                 suffix: IconButton(
//                   icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
//                       color: cs.primary),
//                   onPressed: () => setState(() => _obscure = !_obscure),
//                 ),
//               ),
//               validator: (v) => (v == null || v.length < 6)
//                   ? 'At least 6 characters'
//                   : null,
//             ),
//             const SizedBox(height: 16),
//             FilledButton.icon(
//               icon: _busy
//                   ? const SizedBox(
//                       height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
//                   : const Icon(Icons.login),
//               label: const Text('Sign in'),
//               onPressed: () async {
//                 if (!_form.currentState!.validate()) return;

//                 try {
//                   // 1) Auth
//                   final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
//                     email: _email.text.trim(),
//                     password: _password.text,
//                   );

//                   final uid = cred.user!.uid;

//                   // 2) Ensure the /users/{uid} doc exists with at least a role
//                   final users = FirebaseFirestore.instance.collection('users');
//                   final userDoc = await users.doc(uid).get();
//                   if (!userDoc.exists) {
//                     await users.doc(uid).set({
//                       'role': 'parent',
//                       'familyId': null,
//                       'memberId': null,
//                     });
//                   }

//                   // 3) Route to parent flow (if familyId is null, send to family setup)
//                   final data = (await users.doc(uid).get()).data() ?? {};
//                   final familyId = data['familyId'];
//                   if (familyId == null && context.mounted) {
//                     Navigator.of(context).pushReplacementNamed('/parent-setup');
//                   } else if (context.mounted) {
//                     Navigator.of(context).pushReplacementNamed('/parent');
//                   }
//                 } on FirebaseAuthException catch (e) {
//                   if(context.mounted){
//                     ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text(e.message ?? 'Sign-in failed')),
//                   );
//                   }
                  
//                 }
//               },
//             ),
//             FilledButton(
//               onPressed: () {
//                 // Take them to the kid join flow
//                 Navigator.of(context).pushNamed('/kid-join');
//               },
//               child: const Text('Kid Login (Join with Code)'),
//             ),
//             const SizedBox(height: 8),
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pushReplacementNamed('/register');
//               },
//               child: Text("Don't have an account? Create one",
//                   style: TextStyle(color: cs.secondary)),
//             ),
//             const SizedBox(height: 4),
//             Align(
//               alignment: Alignment.centerRight,
//               child: TextButton(
//                 onPressed: () {}, // TODO: forgot password
//                 child: Text('Forgot password?',
//                     style: TextStyle(color: cs.tertiary)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
