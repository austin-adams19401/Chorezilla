//Auth
import 'package:chorezilla/auth/auth_gate.dart';
import 'package:chorezilla/pages/family_setup/parent_setup_screen.dart';
//Pages
import 'package:chorezilla/pages/startup/login_page.dart';
import 'package:chorezilla/pages/startup/kid_join_page.dart';
import 'package:chorezilla/pages/startup/parent_join_page.dart';
import 'package:chorezilla/pages/startup/register_page.dart';

import 'package:chorezilla/pages/kid_pages/kid_dashboard.dart';
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
import 'package:firebase_messaging/firebase_messaging.dart';
//App State
import 'package:chorezilla/state/app_state.dart';

/// 🔔 FCM background handler
/// Must be a top-level function.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Re-init Firebase in the background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('BG message: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background handler for FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final repo = ChorezillaRepo(firebaseDB: FirebaseFirestore.instance);
  final auth = FirebaseAuth.instance;

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(repo: repo, auth: auth)
        ..attachAuthListener()
        ..loadViewMode(),
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
      themeMode: ThemeMode.light,
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
        '/kids': (_) => const ChildDashboardPage(),
        // Join family with a code
        '/kid-join': (_) => const KidJoinPage(),
        '/parent-join': (_) => const ParentJoinPage(),
      },
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return NotificationTapHandler(child: child);
      },
    );
  }
}

class NotificationTapHandler extends StatefulWidget {
  const NotificationTapHandler({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationTapHandler> createState() => _NotificationTapHandlerState();
}

class _NotificationTapHandlerState extends State<NotificationTapHandler> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _setupNotificationListeners();
  }

  Future<void> _setupNotificationListeners() async {
    if (_initialized) return;
    _initialized = true;

    // 1) If the app was launched by tapping a notification (cold start)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // 2) If the app was in background and the user tapped the notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    if (type == 'assignment_review') {
      final assignmentId = data['assignmentId'] ?? '';
      final familyId = data['familyId'];

      debugPrint(
        'NotificationTapHandler: assignment_review tapped (family=$familyId, assignment=$assignmentId)',
      );

      final app = context.read<AppState>();
      if (assignmentId.isNotEmpty) {
        app.setAssignmentReviewIntent(assignmentId: assignmentId);
      }

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/parent', (route) => false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
