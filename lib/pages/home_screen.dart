import 'package:chorezilla/components/profile_header.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      title: const Text('Chorezilla'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: const ProfileHeader(),
      ),
    ),
      body: Center(
        child: FilledButton(
          onPressed: () {
            // pretend logout → back to login
            Navigator.of(context).pushReplacementNamed('/login');
          },
          child: const Text('Log out'),
        ),
      ),
    );
  }
}
