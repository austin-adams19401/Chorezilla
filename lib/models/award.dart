import 'package:chorezilla/models/family.dart';

class Award {        
  final int xp;  
  final int coins;      

  const Award({         
    required this.xp,
    required this.coins,
  });
}

Award calcAwards({required int difficulty, required FamilySettings settings}) {
  if (difficulty == 0) return const Award(xp: 0, coins: 0);
  final safeDifficulty = difficulty.clamp(1, 5);
  final xp =
      settings.difficultyToXP[safeDifficulty] ??
      (safeDifficulty * 10);
  final coins = (xp * settings.coinPerPoint).round();

  return Award(xp: xp, coins: coins);
}
