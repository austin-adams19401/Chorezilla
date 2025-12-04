// lib/state/app_state_history_allowance.dart
part of 'app_state.dart';

extension AppStateHistoryAllowance on AppState {
  // Public view of allowance configs (read-only map)
  Map<String, AllowanceConfig> get allowanceByMemberId =>
      Map.unmodifiable(_allowanceByMemberId);

  AllowanceConfig allowanceForMember(String memberId) {
    return _allowanceByMemberId[memberId] ?? AllowanceConfig.disabled();
  }

  Future<void> updateAllowanceForMember(
    String memberId,
    AllowanceConfig config,
  ) async {
    _allowanceByMemberId[memberId] = config;
    _notifyStateChanged();

    final famId = _familyId;
    if (famId == null) return;

    await repo.updateMember(famId, memberId, {
      'allowanceEnabled': config.enabled,
      'allowanceFullAmountCents': config.fullAmountCents,
      'allowanceDaysRequired': config.daysRequiredForFull,
      'allowancePayDay': config.payDay,
    });
  }

  /// For the given weekStart (Mon-based), create pending allowance
  /// redemptions for all kids with enabled allowance and a positive payout.
  ///
  /// Assumes you've already called [watchHistoryWeek(weekStart)] at least once
  /// so that [_historyAssignments] and overrides are in a consistent state.
  Future<void> createAllowanceRewardsForWeek(DateTime weekStart) async {
    final famId = _familyId;
    if (famId == null) return;

    final histories = buildWeeklyHistory(weekStart);
    final weekEnd = weekStart.add(const Duration(days: 6));

    for (final h in histories) {
      final config = h.allowanceConfig;
      final result = h.allowanceResult;

      if (!config.enabled) continue;
      if (result == null) continue;
      if (result.payoutCents <= 0) {
        continue; // kid didn't earn anything this week
      }

      await repo.createWeeklyAllowanceRedemption(
        famId,
        memberId: h.member.id,
        payoutCents: result.payoutCents,
        weekStart: weekStart,
        weekEnd: weekEnd,
      );
    }
  }

  /// Auto-create allowance rewards for a given week *if* that week has
  /// completely finished (weekEnd < today).
  ///
  /// Safe to call repeatedly; underlying writes are idempotent.
  Future<void> ensureAllowanceRewardsForWeekIfEligible(
    DateTime weekStart,
  ) async {
    final today = normalizeDate(DateTime.now());
    final weekEnd = weekStart.add(const Duration(days: 6));

    // Only auto-pay for weeks that are fully in the past.
    if (!weekEnd.isBefore(today)) {
      return;
    }

    await createAllowanceRewardsForWeek(weekStart);
  }

  // Keep rewards snapshot logic close by since it feeds the same VN.
  void _applyRewardsSnapshot(List<Reward> newRewards) {
    _rewards = newRewards;
    rewardsVN.value = newRewards; // keep ValueNotifier in sync

    if (!_rewardsBootstrapped) {
      _rewardsBootstrapped = true;
    }
    _notifyStateChanged();
  }

  /// Get the status for a specific kid + date.
  /// Priority:
  /// 1) Manual override (e.g., parent excused the day).
  /// 2) Auto-computed from assignments for the currently watched history week.
  /// 3) Fallback to noChores.
  DayStatus dayStatusFor(String memberId, DateTime date) {
    final key = _dateKey(date);

    // 1) Manual override
    final manual = _dayStatusByMemberId[memberId]?[key];
    if (manual != null) return manual;

    // 2) Auto from assignments if this date is in the watched history week
    if (_historyWeekStart != null) {
      final ws = weekStartFor(date);
      if (ws.isAtSameMomentAs(_historyWeekStart!)) {
        return _computeDayStatusFromAssignments(memberId, date);
      }
    }

    // 3) Default
    return DayStatus.noChores;
  }

  String _dayStatusToWire(DayStatus status) {
    switch (status) {
      case DayStatus.completed:
        return 'completed';
      case DayStatus.missed:
        return 'missed';
      case DayStatus.excused:
        return 'excused';
      case DayStatus.noChores:
        return 'noChores';
    }
  }

  DayStatus _dayStatusFromWire(String raw) {
    switch (raw) {
      case 'completed':
        return DayStatus.completed;
      case 'missed':
        return DayStatus.missed;
      case 'excused':
        return DayStatus.excused;
      case 'noChores':
      default:
        return DayStatus.noChores;
    }
  }

  Future<void> setDayStatus({
    required String memberId,
    required DateTime date,
    required DayStatus status,
  }) async {
    final key = _dateKey(date);
    final map = _dayStatusByMemberId.putIfAbsent(memberId, () => {});
    map[key] = status;
    _notifyStateChanged();

    final famId = _familyId;
    if (famId == null) return;

    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final overrides = famRef.collection('dayStatusOverrides');

    final day = normalizeDate(date);
    final docId = '${memberId}_$key';

    if (status == DayStatus.noChores) {
      // Optional: removing override removes the manual flag and falls back to auto
      await overrides.doc(docId).delete();
    } else {
      await overrides.doc(docId).set({
        'memberId': memberId,
        'date': Timestamp.fromDate(day),
        'status': _dayStatusToWire(status),
      }, SetOptions(merge: true));
    }
  }

  DayStatus _computeDayStatusFromAssignments(String memberId, DateTime date) {
    if (_historyAssignments.isEmpty) return DayStatus.noChores;

    final day = normalizeDate(date);
    final targetKey = _dateKey(day);

    var anyAssignments = false;
    var allDone = true;

    for (final asn in _historyAssignments) {
      if (asn.memberId != memberId) continue;

      final due = asn.due;
      if (due == null) continue;

      final dueDay = normalizeDate(due);
      if (_dateKey(dueDay) != targetKey) continue;

      anyAssignments = true;

      if (asn.status != AssignmentStatus.pending &&
          asn.status != AssignmentStatus.completed) {
        allDone = false;
      }
    }

    if (!anyAssignments) return DayStatus.noChores;
    return allDone ? DayStatus.completed : DayStatus.missed;
  }

  String _dateKey(DateTime date) {
    final d = normalizeDate(date);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  void watchHistoryWeek(DateTime weekStart) {
    final famId = _familyId;
    if (famId == null) {
      _historyAssignmentsSub?.cancel();
      _historyAssignmentsSub = null;
      _historyAssignments = const [];
      _historyWeekStart = null;
      return;
    }

    final ws = weekStartFor(weekStart); // Monday-based
    if (_historyWeekStart != null && _historyWeekStart!.isAtSameMomentAs(ws)) {
      return;
    }

    _historyWeekStart = ws;
    _historyAssignmentsSub?.cancel();

    final end = ws.add(const Duration(days: 7));
    _historyAssignmentsSub = repo
        .watchAssignmentsDueRange(famId, start: ws, end: end)
        .listen((list) {
          _historyAssignments = list;
          _notifyStateChanged();
        });

    // Fire-and-forget load of manual overrides for this week
    _loadDayOverridesForWeek(famId, ws, end);
  }

  Future<void> _loadDayOverridesForWeek(
    String familyId,
    DateTime start,
    DateTime end,
  ) async {
    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(familyId);
    final overrides = famRef.collection('dayStatusOverrides');

    final snap = await overrides
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final memberId = data['memberId'] as String? ?? '';
      final ts = data['date'] as Timestamp?;
      final statusStr = data['status'] as String? ?? '';

      if (memberId.isEmpty || ts == null) continue;

      final day = normalizeDate(ts.toDate());
      final key = _dateKey(day);
      final status = _dayStatusFromWire(statusStr);

      final map = _dayStatusByMemberId.putIfAbsent(memberId, () => {});
      map[key] = status;
    }

    _notifyStateChanged();
  }

  /// View model for a single kid for one week.
  List<WeeklyKidHistory> buildWeeklyHistory(DateTime weekStart) {
    final List<Member> kids = members
        .where((m) => m.role == FamilyRole.child)
        .toList();

    final result = <WeeklyKidHistory>[];

    for (final kid in kids) {
      final allowance = allowanceForMember(kid.id);

      final dayStatuses = <DayStatus>[];
      int completed = 0;
      int excused = 0;
      int missed = 0;

      for (var i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final status = dayStatusFor(kid.id, date);
        dayStatuses.add(status);

        switch (status) {
          case DayStatus.completed:
            completed++;
            break;
          case DayStatus.excused:
            excused++;
            break;
          case DayStatus.missed:
            missed++;
            break;
          case DayStatus.noChores:
            break;
        }
      }

      final allowanceResult = allowance.enabled
          ? computeAllowance(
              config: allowance,
              completedDays: completed,
              excusedDays: excused,
              missedDays: missed,
            )
          : null;

      result.add(
        WeeklyKidHistory(
          member: kid,
          weekStart: weekStart,
          dayStatuses: dayStatuses,
          allowanceConfig: allowance,
          allowanceResult: allowanceResult,
        ),
      );
    }

    return result;
  }
}

/// A ready-to-render view model for the parent history tab.
class WeeklyKidHistory {
  final Member member;
  final DateTime weekStart;
  final List<DayStatus> dayStatuses; // length 7, Mon–Sun
  final AllowanceConfig allowanceConfig;
  final AllowanceResult? allowanceResult;

  WeeklyKidHistory({
    required this.member,
    required this.weekStart,
    required this.dayStatuses,
    required this.allowanceConfig,
    required this.allowanceResult,
  });

  int get completedDays =>
      dayStatuses.where((s) => s == DayStatus.completed).length;

  int get excusedDays =>
      dayStatuses.where((s) => s == DayStatus.excused).length;

  int get missedDays => dayStatuses.where((s) => s == DayStatus.missed).length;
}
