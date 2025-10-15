import 'package:chorezilla/models/family.dart';

class Award {        
  final int xp;  
  final int coins;      

  const Award({         
    required this.xp,
    required this.coins,
  });
}

Award calcAwards({
  required int difficulty,
  required FamilySettings settings,
}) {
  final xp = settings.difficultyToXP[difficulty] ?? 0;
  final coins = (xp * settings.coinPerPoint).round();

  return Award(xp: xp, coins: coins);
}