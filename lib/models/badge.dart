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

    // --- Chore count badges ---
    BadgeDefinition(
      id: 'chores_1',
      name: 'First Chore!',
      description: 'You completed your very first chore!',
      unlockHint: 'Complete your first chore.',
      icon: '⭐',
      type: BadgeType.chores,
    ),
    BadgeDefinition(
      id: 'chores_10',
      name: '10 Chores Done',
      description: 'Double digits — you\'re on a roll!',
      unlockHint: 'Complete 10 chores total.',
      icon: '🌈',
      type: BadgeType.chores,
    ),
    BadgeDefinition(
      id: 'chores_25',
      name: '25 Chores Done',
      description: 'You\'re a real helper!',
      unlockHint: 'Complete 25 chores total.',
      icon: '🦸',
      type: BadgeType.chores,
    ),
    BadgeDefinition(
      id: 'chores_50',
      name: '50 Chores Done',
      description: 'Half a hundred chores — incredible!',
      unlockHint: 'Complete 50 chores total.',
      icon: '🚀',
      type: BadgeType.chores,
    ),
    BadgeDefinition(
      id: 'chores_100',
      name: 'Chore Champion',
      description: '100 chores completed — you\'re a legend!',
      unlockHint: 'Complete 100 chores total.',
      icon: '👑',
      type: BadgeType.chores,
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

  static Iterable<BadgeDefinition> choresBadges() =>
      items.where((b) => b.type == BadgeType.chores);
}
