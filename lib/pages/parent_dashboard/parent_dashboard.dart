import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/components/billing_issue_banner.dart';
import 'package:chorezilla/components/chores_nav_icon.dart';
import 'package:chorezilla/components/parent_menu_drawer.dart';
import 'package:chorezilla/components/rewards_nav_icon.dart';
import 'package:chorezilla/components/tutorial_overlay.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/pages/parent_dashboard/chore_editor_sheet.dart';
import 'package:chorezilla/pages/parent_dashboard/manage_chores_tab.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_history_tab.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_notifications.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_rewards_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parent_today_tab.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage>
    with WidgetsBindingObserver {
  int _index = 0;

  bool _showTutorial = false;
  TutorialStep _tutorialStep = TutorialStep.step1Today;
  TutorialStep? _prevTutorialStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkTutorial();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorialCongrats());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkTutorial() {
    final family = context.read<AppState>().family;
    final done = family?.tutorialComplete ?? false;
    if (!done && mounted) {
      setState(() => _showTutorial = true);
    }
  }

  void _onTutorialAdvance() {
    if (_tutorialStep == TutorialStep.step2Chores) {
      _openChoreSheetThenAdvance();
      return;
    }
    if (_tutorialStep == TutorialStep.step5KidView) {
      _completeWithKidView();
      return;
    }
    setState(() {
      _prevTutorialStep = _tutorialStep;
      switch (_tutorialStep) {
        case TutorialStep.step1Today:
          _tutorialStep = TutorialStep.step2Chores;
          _index = 1;
        case TutorialStep.step2Chores:
          break; // handled above
        case TutorialStep.step3RewardsNav:
          _tutorialStep = TutorialStep.step3bRewardsContent;
          _index = 2;
        case TutorialStep.step3bRewardsContent:
          _tutorialStep = TutorialStep.step4HistoryNav;
        case TutorialStep.step4HistoryNav:
          _tutorialStep = TutorialStep.step4bHistoryContent;
          _index = 3;
        case TutorialStep.step4bHistoryContent:
          _tutorialStep = TutorialStep.step5KidView;
        case TutorialStep.step5KidView:
          break; // handled above
      }
    });
  }

  Future<void> _openChoreSheetThenAdvance() async {
    final app = context.read<AppState>();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChoreEditorSheet(family: app.family!),
    );
    if (!mounted) return;
    setState(() {
      _prevTutorialStep = _tutorialStep;
      _tutorialStep = TutorialStep.step3RewardsNav;
    });
  }

  Future<void> _checkTutorialCongrats() async {
    final prefs = await SharedPreferences.getInstance();
    final show = prefs.getBool('showTutorialCongrats') ?? false;
    if (!show || !mounted) return;
    await prefs.setBool('showTutorialCongrats', false);
    if (!mounted) return;

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.celebration_rounded, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You're ready to roll!",
                style: ts.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          "Setup complete. Fill the rewards store with prizes your kids actually care about, assign some chores, and let Chorezilla do the nagging. Your family is about to get a whole lot more organized.",
          style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Let's go!"),
          ),
        ],
      ),
    );
  }

  Future<void> _resetTutorial() async {
    final app = context.read<AppState>();
    final familyId = app.family?.id;
    if (familyId != null) {
      await app.repo.updateFamily(familyId, {'tutorialComplete': false});
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showKidViewTutorial', false);
    if (!mounted) return;
    setState(() {
      _tutorialStep = TutorialStep.step1Today;
      _prevTutorialStep = null;
      _index = 0;
      _showTutorial = true;
    });
  }

  void _completeTutorial() {
    setState(() => _showTutorial = false);
    final app = context.read<AppState>();
    final familyId = app.family?.id;
    if (familyId != null) {
      app.repo.updateFamily(familyId, {'tutorialComplete': true});
    }
  }

  Future<void> _completeWithKidView() async {
    setState(() => _showTutorial = false);
    final app = context.read<AppState>();
    final familyId = app.family?.id;
    if (familyId != null) {
      await app.repo.updateFamily(familyId, {'tutorialComplete': true});
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showKidViewTutorial', true);
    if (!mounted) return;
    await app.setViewMode(AppViewMode.kid);
  }

  @override
  Widget build(BuildContext context) {
    final isReady = context.select((AppState s) => s.isReady);
    if (!isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;
    final navTarget = context.select((AppState s) => s.pendingNavTarget);

    if (navTarget == 'parent_approve' && _index != 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _index = 1);
      });
    }

    final pages = [
      const ParentTodayTab(),
      ParentChoresTab(
        initialTabIndex: navTarget == 'parent_approve' ? 1 : 0,
      ),
      const ParentRewardsPage(),
      const ParentHistoryTab(),
    ];

    final isToday = _index == 0;
    final Color appBarTextColor = cs.onSecondary;

    final scaffold = Scaffold(
      extendBodyBehindAppBar: isToday,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: appBarTextColor),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'Chorezilla',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: appBarTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: appBarTextColor),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Reset tutorial',
              onPressed: _resetTutorial,
            ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: appBarTextColor),
            onPressed: () async {
              final app = context.read<AppState>();
              await app.setViewMode(AppViewMode.kid);
            },
            icon: const Icon(Icons.family_restroom_rounded),
            label: const Text(
              'Kid view',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      drawer: const ParentDrawer(),
      body: Column(
        children: [
          const ParentNotificationRegistrar(),
          Builder(
            builder: (context) {
              final family = context.watch<AppState>().family;
              if (family == null) return const SizedBox.shrink();
              return BillingIssueBanner(family: family);
            },
          ),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(
            color: Colors.grey, width: 2.0 ))
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              icon: ChoresNavIcon(selected: false),
              selectedIcon: ChoresNavIcon(selected: true),
              label: 'Chores',
            ),
            NavigationDestination(
              icon: RewardsNavIcon(selected: false),
              selectedIcon: RewardsNavIcon(selected: true),
              label: 'Rewards',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'History',
            ),
          ],
        ),
      ),
    );

    if (!_showTutorial) return scaffold;

    return Stack(
      children: [
        scaffold,
        TutorialOverlay(
          step: _tutorialStep,
          previousStep: _prevTutorialStep,
          onAdvance: _onTutorialAdvance,
          onSkip: _completeTutorial,
        ),
      ],
    );
  }
}
