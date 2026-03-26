part of 'app_state.dart';

extension AppStateAuth on AppState {
  // Allow main.dart to call this explicitly; safe to call more than once.
  void attachAuthListener() {
    debugPrint('ATTACHING AUTH LISTENER');
    _authSub ??= auth.authStateChanges().listen(_onAuthChanged);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Auth flow
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _onAuthChanged(User? u) async {
    debugPrint('AUTH CHANGED!');

    _firebaseUser = u;

    if (u == null) {
      debugPrint('AUTH CHANGED: user is null, teardown');
      await _teardown();
      return;
    }

    debugPrint('AUTH CHANGED: user=${u.uid} - ${u.displayName}');
    await _getDataForUser(u);

    // Ensure anyone watching AppState rebuilds after auth change
    _notifyStateChanged();
  }

  Future<void> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize(
      clientId:
          '588085741239-auq29s1kutqjjto23re395l76m8t1o9a.apps.googleusercontent.com',
      serverClientId:
          '588085741239-tetqvu3rths6h7s5paoj2qvvham46sfg.apps.googleusercontent.com',
    );

    if (kIsWeb || !GoogleSignIn.instance.supportsAuthenticate()) {
      // Web or fallback path
      final provider = GoogleAuthProvider();
      final uc = await auth.signInWithPopup(provider);
      debugPrint(
        'GOOGLE SIGN IN: WEB user=${uc.user?.uid} - ${uc.user?.displayName}',
      );
      // No need to call _getDataForUser here; _onAuthChanged will fire.
      return;
    }

    final account = await GoogleSignIn.instance.authenticate();

    final authData = account.authentication;
    final idToken = authData.idToken;

    if (idToken == null) {
      debugPrint('Google returned no idToken. Check client IDs / platform setup.');
      throw Exception('Google sign-in failed. Check your app configuration.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCred = await auth.signInWithCredential(credential);

    debugPrint(
      'GOOGLE SIGN IN: user=${userCred.user?.uid} - ${userCred.user?.displayName}',
    );
  }

  Future<void> _getDataForUser(User u) async {
    // 1) Ensure profile exists & fetch it
    debugPrint('_getDataForUser: ${u.email} - ${u.displayName}');
    PurchaseService.logIn(u.uid).ignore(); // link RevenueCat to Firebase UID
    final profile = await repo.checkForUserProfile(
      u.uid,
      displayName: u.displayName,
      email: u.email,
    );

    _user = profile;
    String? famId = profile.defaultFamilyId;

    debugPrint(
      '_getDataForUser: email:${_user?.email} - name: ${_user?.displayName} - famId: $famId',
    );

    if (_familyId != famId) {
      _familyId = famId;
    }

    if (famId != null && famId.isNotEmpty) {
      await _startFamilyStreams(famId);
    }

    _notifyStateChanged();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Profile & family helpers
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> refreshAfterProfileChange() async {
    final u = auth.currentUser;
    if (u == null) return;
    final profile = await repo.checkForUserProfile(
      u.uid,
      displayName: u.displayName,
      email: u.email,
    );
    _user = profile;
    if (_familyId != profile.defaultFamilyId &&
        profile.defaultFamilyId != null) {
      _familyId = profile.defaultFamilyId;
      await _startFamilyStreams(_familyId!);
    }
    _notifyStateChanged();
  }

  // Invite helpers
  Future<String> ensureJoinCode() async {
    final famId = _familyId!;
    return repo.ensureJoinCode(famId);
  }

  Future<String?> redeemJoinCode(String code) {
    return repo.redeemJoinCode(code);
  }
}
