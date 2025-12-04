part of 'app_state.dart';

extension AppStateUi on AppState {
  // ───────────────────────────────────────────────────────────────────────────
  // Notification nav intent
  // ───────────────────────────────────────────────────────────────────────────
  void setAssignmentReviewIntent({required String assignmentId}) {
    _pendingNavTarget = 'parent_approve';
    _pendingAssignmentId = assignmentId;
    _notifyStateChanged();
  }

  void clearNavIntent() {
    _pendingNavTarget = null;
    _pendingAssignmentId = null;
    _notifyStateChanged();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Theme
  // ───────────────────────────────────────────────────────────────────────────
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _notifyStateChanged();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // View mode (Parent vs Kid) – persisted on device
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_viewModeKey);

    if (v == 'kid') {
      _viewMode = AppViewMode.kid;
    } else {
      _viewMode = AppViewMode.parent;
    }

    _viewModeLoaded = true;
    _notifyStateChanged();
  }

  /// Persist view mode to local storage and notify listeners.
  Future<void> setViewMode(AppViewMode mode) async {
    if (_viewMode == mode) return;

    _viewMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _viewModeKey,
      mode == AppViewMode.kid ? 'kid' : 'parent',
    );
    _notifyStateChanged();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Active member selection for kid dashboard/profile header
  // ───────────────────────────────────────────────────────────────────────────
  void setCurrentMember(String? memberId) {
    debugPrint('setCurrentMember: old=$_currentMemberId new=$memberId');

    if (_currentMemberId == memberId) return;
    if (_currentMemberId != null) stopKidStreams(_currentMemberId!);
    _currentMemberId = memberId;
    if (memberId != null) startKidStreams(memberId);
    _notifyStateChanged();
  }
}
