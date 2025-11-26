import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        
      ),
      
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(25),
            child: Text('Enter your email and we will send you a password reset link',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20)),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
            child: TextFormField(
                  controller: _email,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.lightGreen, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.lightGreen),
                      borderRadius: BorderRadius.circular(12)
                    ),
                    fillColor: Colors.grey[200],
                    filled: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty){
                      return 'Email is required';
                    }
                    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                    return ok ? null : 'Enter a valid email';
                  },
                ),
          ),    
          MaterialButton(
            onPressed: (){ passwordReset(); },
            color: Colors.green,
            child: Text('Reset Password')
          )    
        ],
      )
    );
  }
  
  Future passwordReset() async {
    try{
      await FirebaseAuth.instance
        .sendPasswordResetEmail(email: _email.text.trim());
      showDialog(context: context, builder: (context){
        return AlertDialog(content: Text('Password reset link sent! Please check your email.'));
      });
    } on FirebaseAuthException catch (e) {
      showDialog(context: context, builder: (context){
        return AlertDialog(content: Text(e.message.toString()));
      });
    }

  }
}