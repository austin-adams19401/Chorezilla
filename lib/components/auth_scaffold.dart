import 'package:flutter/material.dart';
import 'package:chorezilla/components/mascot_header.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.headerTitle, required this.child, required this.headerSubtitle});
  final String headerTitle;
  final String headerSubtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.secondary,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              MascotHeader(title: headerTitle, subtitle: headerSubtitle),
              const SizedBox(height: 8),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    color: cs.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}