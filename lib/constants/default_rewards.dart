import 'package:chorezilla/models/reward.dart';

class DefaultReward {
  final String title;
  final String description;
  final String icon;
  final int coinCost;
  final RewardCategory category;

  const DefaultReward({
    required this.title,
    required this.description,
    required this.icon,
    required this.coinCost,
    required this.category,
  });
}

const List<DefaultReward> kDefaultRewards = [
  // Snacks & Treats
  DefaultReward(
    title: 'Candy',
    description: 'Pick out a piece of candy.',
    icon: '🍬',
    coinCost: 5,
    category: RewardCategory.snack,
  ),
  DefaultReward(
    title: 'Choose Dessert',
    description: 'Pick what dessert the family has tonight.',
    icon: '🍰',
    coinCost: 10,
    category: RewardCategory.snack,
  ),
  DefaultReward(
    title: 'Ice Cream',
    description: 'Get a scoop of your favorite ice cream.',
    icon: '🍦',
    coinCost: 15,
    category: RewardCategory.snack,
  ),
  DefaultReward(
    title: 'Bake Cookies Together',
    description: 'Bake a batch of cookies with a parent.',
    icon: '🍪',
    coinCost: 20,
    category: RewardCategory.snack,
  ),
  DefaultReward(
    title: 'Gas Station Treat',
    description: 'Pick out a snack or drink on a gas station run.',
    icon: '🏪',
    coinCost: 20,
    category: RewardCategory.snack,
  ),
  DefaultReward(
    title: 'Choose Dinner',
    description: 'Pick what the family has for dinner tonight.',
    icon: '🍽️',
    coinCost: 20,
    category: RewardCategory.snack,
  ),
  DefaultReward(
    title: 'Pizza Night',
    description: 'The family orders pizza for dinner.',
    icon: '🍕',
    coinCost: 40,
    category: RewardCategory.snack,
  ),

  // Time & Privileges
  DefaultReward(
    title: 'Bedtime Story',
    description: 'Get an extra bedtime story read to you.',
    icon: '📖',
    coinCost: 10,
    category: RewardCategory.time,
  ),
  DefaultReward(
    title: 'Choose Car Music',
    description: 'You control the music on the next car ride.',
    icon: '🎵',
    coinCost: 20,
    category: RewardCategory.time,
  ),
  DefaultReward(
    title: 'Extra Screen Time',
    description: 'Get 30 extra minutes of screen time.',
    icon: '📱',
    coinCost: 20,
    category: RewardCategory.time,
  ),
  DefaultReward(
    title: 'Stay Up 30 Minutes Late',
    description: 'Stay up 30 minutes past your normal bedtime.',
    icon: '🌙',
    coinCost: 30,
    category: RewardCategory.time,
  ),
  DefaultReward(
    title: 'Skip a Chore',
    description: 'Get a one-time pass to skip any single chore.',
    icon: '🙌',
    coinCost: 30,
    category: RewardCategory.time,
  ),
  DefaultReward(
    title: 'Breakfast in Bed',
    description: 'Have breakfast brought to you in bed.',
    icon: '🍳',
    coinCost: 25,
    category: RewardCategory.time,
  ),

  // Experiences
  DefaultReward(
    title: 'Build a Fort',
    description: 'Build a blanket fort in the living room.',
    icon: '🏕️',
    coinCost: 20,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Park Trip',
    description: 'Head to the park for some outdoor fun.',
    icon: '🛝',
    coinCost: 20,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Backyard Campfire',
    description: "Have a campfire with s'mores in the backyard.",
    icon: '🔥',
    coinCost: 30,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Game Night',
    description: 'Pick the board game or card game for family game night.',
    icon: '🎲',
    coinCost: 40,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Movie Night',
    description: 'Pick the movie for family movie night.',
    icon: '🎬',
    coinCost: 40,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Pool or Splash Pad',
    description: 'A trip to the pool or splash pad.',
    icon: '🏊',
    coinCost: 50,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Bowling Trip',
    description: 'Go bowling as a family or with a friend.',
    icon: '🎳',
    coinCost: 80,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Mini Golf',
    description: 'Play a round of mini golf.',
    icon: '⛳',
    coinCost: 80,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Go to the Movies',
    description: 'Pick a movie to see at the theater.',
    icon: '🎟️',
    coinCost: 150,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Go to Arcade',
    description: 'Spend some time at the arcade.',
    icon: '🕹️',
    coinCost: 150,
    category: RewardCategory.experience,
  ),
  DefaultReward(
    title: 'Go to a Sports Game',
    description: 'Attend a live sporting event.',
    icon: '🏟️',
    coinCost: 400,
    category: RewardCategory.experience,
  ),

  // Toys & Items
  DefaultReward(
    title: 'New Book',
    description: 'Pick out a new book to keep.',
    icon: '📚',
    coinCost: 50,
    category: RewardCategory.toy,
  ),
  DefaultReward(
    title: 'New Toy',
    description: 'Pick out a new toy within a set budget.',
    icon: '🧸',
    coinCost: 80,
    category: RewardCategory.toy,
  ),
  DefaultReward(
    title: 'New Video Game',
    description: 'Pick out a new video game or app.',
    icon: '🎮',
    coinCost: 150,
    category: RewardCategory.toy,
  ),

  // Money
  DefaultReward(
    title: r'$5 Cash',
    description: r'Earn $5 to spend however you like.',
    icon: '💵',
    coinCost: 80,
    category: RewardCategory.money,
  ),
  DefaultReward(
    title: r'$20 Cash',
    description: r'Earn $20 to spend however you like.',
    icon: '💴',
    coinCost: 250,
    category: RewardCategory.money,
  ),
  DefaultReward(
    title: r'$100 Cash',
    description: r'Earn $100 to spend however you like.',
    icon: '💰',
    coinCost: 750,
    category: RewardCategory.money,
  ),
];
