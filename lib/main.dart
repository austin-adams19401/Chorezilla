//Auth
import 'package:chorezilla/auth/auth_gate.dart';
import 'package:chorezilla/pages/family_setup/parent_setup_screen.dart';
//Pages
import 'package:chorezilla/pages/startup/login_page.dart';
import 'package:chorezilla/pages/startup/kid_join_page.dart';
import 'package:chorezilla/pages/startup/parent_join_page.dart';
import 'package:chorezilla/pages/startup/register_page.dart';

import 'package:chorezilla/pages/kid_pages/child_dashboard.dart';
import 'package:chorezilla/pages/family_setup/add_kids_page.dart';
import 'package:chorezilla/pages/family_setup/edit_family_page.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_dashboard.dart';
import 'package:chorezilla/themes/app_theme.dart';

//Flutter libraries
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
//Firebase
import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chorezilla/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//App State
import 'package:chorezilla/state/app_state.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final repo = ChorezillaRepo(firebaseDB: FirebaseFirestore.instance);
  final auth = FirebaseAuth.instance;

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(repo: repo, auth: auth)..attachAuthListener(),
      child: const Chorezilla(),
    ),
  );
}

class Chorezilla extends StatelessWidget {
  const Chorezilla({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: app.themeMode,
      debugShowCheckedModeBanner: false,
      title: 'Chorezilla',
      home: const AuthGate(),
      routes: {
        // Logins
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        // Family Setup
        '/parent-setup': (_) => const ParentSetupPage(),
        '/add-kids': (_) => const AddKidsPage(),
        '/edit': (_) => const EditFamilyPage(),
        // Dashboards
        '/parent': (_) => const ParentDashboardPage(),
        '/kids' : (_) => const ChildDashboardPage(),
        // Join family with a code
        '/kid-join': (_) => const KidJoinPage(),
        '/parent-join': (_) => const ParentJoinPage(),
      },
    );
  }
}