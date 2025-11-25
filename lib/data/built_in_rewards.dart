// import 'package:chorezilla/models/reward.dart';

// final List<RewardDefinition> builtInRewards = [
//   // 5 coins – tiny treats
//   RewardDefinition(
//     id: 'candy',
//     title: 'Candy / small treat',
//     description: 'One small candy or snack from the treat bin.',
//     icon: '🍬',
//     coinCost: 5,
//     category: RewardCategory.snack,
//   ),
//   RewardDefinition(
//     id: 'sticker',
//     title: 'Sticker or tattoo',
//     icon: '⭐',
//     coinCost: 5,
//     category: RewardCategory.digital,
//   ),

//   // 10 coins
//   RewardDefinition(
//     id: 'dessert',
//     title: 'Pick dessert',
//     description: 'You choose dessert tonight.',
//     icon: '🍰',
//     coinCost: 10,
//     category: RewardCategory.snack,
//   ),
//   RewardDefinition(
//     id: 'treasure_box',
//     title: 'Treasure box pick',
//     icon: '🎁',
//     coinCost: 10,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'choose_dinner',
//     title: 'Choose dinner',
//     icon: '🍽️',
//     coinCost: 10,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'bedtime_story',
//     title: 'Extra bedtime story',
//     icon: '📚',
//     coinCost: 10,
//     category: RewardCategory.time,
//   ),

//   // 20 coins
//   RewardDefinition(
//     id: 'choose_car_music',
//     title: 'Choose car music',
//     icon: '🎵',
//     coinCost: 20,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'double_xp_day',
//     title: 'Double XP for 1 day',
//     description: 'All chores today give double XP.',
//     icon: '✨',
//     coinCost: 20,
//     category: RewardCategory.digital,
//     autoFulfill: true,
//   ),
//   RewardDefinition(
//     id: 'park_trip',
//     title: 'Trip to the park',
//     icon: '🏞️',
//     coinCost: 20,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'extra_backscratch',
//     title: 'Extra back scratch',
//     icon: '💆',
//     coinCost: 20,
//     category: RewardCategory.time,
//   ),

//   // 30 coins
//   RewardDefinition(
//     id: 'stay_up_30',
//     title: 'Stay up 30 min late',
//     icon: '🌙',
//     coinCost: 30,
//     category: RewardCategory.time,
//   ),
//   RewardDefinition(
//     id: 'print_3d',
//     title: '3D print something',
//     icon: '🖨️',
//     coinCost: 30,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'bake_cookies',
//     title: 'Bake cookies together',
//     icon: '🍪',
//     coinCost: 30,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'gas_station_treats',
//     title: 'Gas station treats',
//     icon: '⛽',
//     coinCost: 30,
//     category: RewardCategory.snack,
//   ),

//   // 40 coins
//   RewardDefinition(
//     id: 'game_night',
//     title: 'Game night',
//     icon: '🎮',
//     coinCost: 40,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'movie_night',
//     title: 'Movie night',
//     icon: '🎬',
//     coinCost: 40,
//     category: RewardCategory.experience,
//   ),

//   // 50 coins
//   RewardDefinition(
//     id: 'room_decoration',
//     title: 'New room decoration',
//     icon: '🖼️',
//     coinCost: 50,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'new_toy',
//     title: 'New toy',
//     icon: '🧸',
//     coinCost: 50,
//     category: RewardCategory.experience,
//   ),

//   // 80 coins
//   RewardDefinition(
//     id: 'living_room_sleepover',
//     title: 'Sleepover in living room',
//     icon: '🛏️',
//     coinCost: 80,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'five_dollars',
//     title: '\$5 cash',
//     icon: '💵',
//     coinCost: 80,
//     category: RewardCategory.money,
//   ),

//   // 150 coins
//   RewardDefinition(
//     id: 'new_video_game',
//     title: 'New video game',
//     icon: '🕹️',
//     coinCost: 150,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'bike_upgrade',
//     title: 'Bike upgrade',
//     icon: '🚲',
//     coinCost: 150,
//     category: RewardCategory.experience,
//   ),
//   RewardDefinition(
//     id: 'go_to_arcade',
//     title: 'Go to the arcade',
//     icon: '🎰',
//     coinCost: 150,
//     category: RewardCategory.experience,
//   ),

//   // 750 coins
//   RewardDefinition(
//     id: 'hundred_dollars',
//     title: '\$100',
//     icon: '💰',
//     coinCost: 750,
//     category: RewardCategory.money,
//   ),
//   RewardDefinition(
//     id: 'sports_game',
//     title: 'Go to a sports game',
//     icon: '🏈',
//     coinCost: 750,
//     category: RewardCategory.experience,
//   ),

//   // Digital-only cosmetic stuff (examples)
//   RewardDefinition(
//     id: 'confetti_blast',
//     title: 'Confetti blast',
//     description: 'Next level-up uses a special confetti animation.',
//     icon: '🎉',
//     coinCost: 10,
//     category: RewardCategory.digital,
//     autoFulfill: true,
//   ),
//   RewardDefinition(
//     id: 'avatar_frame',
//     title: 'Avatar glow frame',
//     icon: '🧿',
//     coinCost: 30,
//     category: RewardCategory.digital,
//     autoFulfill: true,
//   ),
// ];
