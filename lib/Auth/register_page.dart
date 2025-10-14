import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await cred.user?.updateDisplayName(_name.text.trim());
      // AuthGate will pick this up and go to setup/dashboard.
      if (mounted) Navigator.of(context).pop(); // Return to login (optional)
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
      appBar: AppBar(title: const Text('Create account')),
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
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Your name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: cs.error)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _register,
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Create account'),
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


// class RegisterPage extends StatefulWidget {
//   const RegisterPage({super.key});
//   @override
//   State<RegisterPage> createState() => _RegisterPageState();
// }

// class _RegisterPageState extends State<RegisterPage> {
//   final _form = GlobalKey<FormState>();
//   final _name = TextEditingController();
//   final _email = TextEditingController();
//   final _password = TextEditingController();
//   final _confirm = TextEditingController();
//   bool _obscure = true;
//   bool _busy = false;

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return AuthScaffold(
//       headerTitle: 'Create your family',
//       child: Form(
//         key: _form,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Text('Register',
//                 style: Theme.of(context)
//                     .textTheme
//                     .titleLarge
//                     ?.copyWith(color: cs.secondary, fontWeight: FontWeight.w700)),
//             const SizedBox(height: 12),
//             TextFormField(
//               controller: _name,
//               decoration: themedInput(context, 'Your name'),
//               validator: (v) => (v == null || v.trim().isEmpty)
//                   ? 'Name is required'
//                   : null,
//             ),
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
//                       color: cs.secondary),
//                   onPressed: () => setState(() => _obscure = !_obscure),
//                 ),
//               ),
//               validator: (v) => (v == null || v.length < 6)
//                   ? 'At least 6 characters'
//                   : null,
//             ),
//             const SizedBox(height: 12),
//             TextFormField(
//               controller: _confirm,
//               obscureText: _obscure,
//               decoration: themedInput(context, 'Confirm password'),
//               validator: (v) =>
//                   (v != _password.text) ? 'Passwords don’t match' : null,
//             ),
//             const SizedBox(height: 16),
//             FilledButton.icon(
//               icon: _busy
//                   ? const SizedBox(
//                       height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
//                   : const Icon(Icons.person_add),
//               label: const Text('Create account'),
//                 onPressed: () async {
//                   if (!_form.currentState!.validate()) return;

//                   try {
//                     // 1) Auth
//                     final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
//                       email: _email.text.trim(),
//                       password: _password.text,
//                     );
//                     final uid = cred.user!.uid;

//                     // 2) Create minimal /users/{uid}
//                     await FirebaseFirestore.instance.collection('users').doc(uid).set({
//                       'role': 'parent',
//                       'familyId': null,
//                       'memberId': null,
//                     });

//                     // 3) Send to family setup
//                     Navigator.of(context).pushReplacementNamed('/family-setup');
//                   } on FirebaseAuthException catch (e) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text(e.message ?? 'Registration failed')),
//                     );
//                   }
//                 },
//               style: FilledButton.styleFrom(
//                 backgroundColor: cs.primary,
//                 foregroundColor: cs.onPrimary,
//               ),
//             ),
//             const SizedBox(height: 8),
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pushReplacementNamed('/login');
//               },
//               child: Text('Already have an account? Sign in',
//                   style: TextStyle(color: cs.secondary)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
