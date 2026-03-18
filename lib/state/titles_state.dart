// lib/state/titles_state.dart
part of 'app_state.dart';

extension TitlesState on AppState {
  /// Check achievement title conditions and award any newly unlocked titles.
  ///
  /// [silentNinja] — pass true when the kid completed all required chores in
  /// one session without leaving the dashboard.
  ///
  /// Returns the list of newly unlocked [CosmeticItem]s (titles only).
  Future<List<CosmeticItem>> checkAndAwardAchievementTitlesForKid(
    String memberId, {
    bool silentNinja = false,
  }) async {
    final member = members.firstWhere(
      (m) => m.id == memberId,
      orElse: () => throw Exception('Member not found'),
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final newTitleIds = <String>[];
    final memberUpdates = <String, dynamic>{};

    // ── Treasure Hoarder ──────────────────────────────────────────────────────
    // Coin balance must stay at or above 100 for 3 continuous days.
    if (member.coins >= 100) {
      if (member.coinsHoardSince == null) {
        // Start the clock.
        memberUpdates['coinsHoardSince'] = Timestamp.fromDate(now);
      } else {
        final daysSince = now.difference(member.coinsHoardSince!).inDays;
        if (daysSince >= 3 &&
            !member.ownedCosmetics.contains('title_treasure_hoarder')) {
          newTitleIds.add('title_treasure_hoarder');
        }
      }
    } else if (member.coinsHoardSince != null) {
      // Coins dropped below 100 — reset.
      memberUpdates['coinsHoardSince'] = null;
    }

    // ── Big Spender ───────────────────────────────────────────────────────────
    // Spent 100+ coins in a single day.
    if (!member.ownedCosmetics.contains('title_big_spender')) {
      final spendDate = member.dailyCoinsSpentDate;
      if (spendDate != null) {
        final spendDay =
            DateTime(spendDate.year, spendDate.month, spendDate.day);
        if (spendDay == today && member.dailyCoinsSpent >= 100) {
          newTitleIds.add('title_big_spender');
        }
      }
    }

    // ── Silent Ninja ──────────────────────────────────────────────────────────
    // Completed all required chores in one session (signalled by caller).
    if (silentNinja &&
        !member.ownedCosmetics.contains('title_silent_ninja')) {
      newTitleIds.add('title_silent_ninja');
    }

    if (newTitleIds.isEmpty && memberUpdates.isEmpty) return const [];

    // Persist the coinsHoardSince update if needed (no new titles yet).
    if (memberUpdates.isNotEmpty) {
      await updateMember(memberId, memberUpdates);
    }

    if (newTitleIds.isEmpty) return const [];

    // Award new titles: add to ownedCosmetics.
    final updatedOwned = [
      ...member.ownedCosmetics,
      ...newTitleIds.where((id) => !member.ownedCosmetics.contains(id)),
    ];
    await updateMember(memberId, {'ownedCosmetics': updatedOwned});

    return newTitleIds
        .map((id) {
          try {
            return CosmeticCatalog.items.firstWhere((c) => c.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<CosmeticItem>()
        .toList();
  }
}
