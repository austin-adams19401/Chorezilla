// lib/models/badge.dart

enum BadgeType { streak, chores, coins, special }

class BadgeDefinition {
  final String id; // e.g. 'streak_3_days'
  final String name; // e.g. '3-Day Streak'
  final String description; // Short kid-friendly description
  final String unlockHint;
  final String icon; // Emoji for now
  final BadgeType type;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockHint,
    required this.icon,
    required this.type,
  });
}

class BadgeCatalog {
  static const List<BadgeDefinition> items = [
    // --- Streak badges ---
    BadgeDefinition(
      id: 'streak_3_days',
      name: '3-Day Streak',
      description: 'You did chores 3 days in a row!',
      unlockHint: 'Complete at least 1 chore per day for 3 days.',
      icon: '🔥',
      type: BadgeType.streak,
    ),
    BadgeDefinition(
      id: 'streak_7_days',
      name: '7-Day Streak',
      description: 'A whole week of chores in a row!',
      unlockHint: 'Complete at least 1 chore per day for 7 days.',
      icon: '🌟',
      type: BadgeType.streak,
    ),
    BadgeDefinition(
      id: 'streak_14_days',
      name: '14-Day Streak',
      description: 'Two weeks of awesome habits!',
      unlockHint: 'Complete at least 1 chore per day for 14 days.',
      icon: '💪',
      type: BadgeType.streak,
    ),
    BadgeDefinition(
      id: 'streak_30_days',
      name: '30-Day Streak',
      description: 'An entire month without breaking the chain!',
      unlockHint: 'Complete at least 1 chore per day for 30 days.',
      icon: '🏆',
      type: BadgeType.streak,
    ),
  ];

  static BadgeDefinition? byId(String id) {
    try {
      return items.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  static Iterable<BadgeDefinition> streakBadges() =>
      items.where((b) => b.type == BadgeType.streak);
}
