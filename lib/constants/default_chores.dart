import 'package:chorezilla/models/chore.dart';

class DefaultChore {
  final String title;
  final String description;
  final String icon;
  final ChoreCategory category;

  const DefaultChore({
    required this.title,
    required this.description,
    required this.icon,
    this.category = ChoreCategory.other,
  });
}

const List<DefaultChore> kDefaultChores = [
  // Dishes & Kitchen
  DefaultChore(
    title: 'Do the Dishes',
    description: 'Wash, rinse, and dry all dishes in the sink.',
    icon: '🍽️',
    category: ChoreCategory.dishes,
  ),
  DefaultChore(
    title: 'Load the Dishwasher',
    description: 'Rinse dishes and load them neatly into the dishwasher.',
    icon: '🍽️',
    category: ChoreCategory.dishes,
  ),
  DefaultChore(
    title: 'Unload the Dishwasher',
    description: 'Put away all clean dishes and utensils from the dishwasher.',
    icon: '🍽️',
    category: ChoreCategory.dishes,
  ),
  DefaultChore(
    title: 'Wipe Down Counters',
    description: 'Wipe kitchen and bathroom counters clean with a damp cloth.',
    icon: '🧽',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Wipe the Stove',
    description: 'Wipe down burners and stove surface after cooking.',
    icon: '🍳',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Clean the Microwave',
    description: 'Wipe inside and outside of the microwave until clean.',
    icon: '🧊',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Set the Table',
    description: 'Place plates, silverware, and cups for each person.',
    icon: '🍴',
    category: ChoreCategory.dishes,
  ),
  DefaultChore(
    title: 'Clear the Table',
    description: 'Remove dishes, wipe the table, and push in chairs.',
    icon: '🍴',
    category: ChoreCategory.dishes,
  ),

  // Floors & General Cleaning
  DefaultChore(
    title: 'Sweep the Floor',
    description: 'Sweep floors and collect dirt into the dustpan.',
    icon: '🧹',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Mop the Floor',
    description: 'Mop hard floors until clean and dry.',
    icon: '🪣',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Vacuum',
    description: 'Vacuum all carpeted areas in the assigned rooms.',
    icon: '🧹',
    category: ChoreCategory.cleaning,
  ),

  // Trash
  DefaultChore(
    title: 'Take Out the Trash',
    description: 'Replace trash bags and take bins to the designated area.',
    icon: '🗑️',
    category: ChoreCategory.trash,
  ),
  DefaultChore(
    title: 'Take Out the Recycling',
    description: 'Sort and take recycling to the bin outside.',
    icon: '♻️',
    category: ChoreCategory.trash,
  ),

  // Laundry
  DefaultChore(
    title: 'Start the Laundry',
    description: 'Sort clothes, add detergent, and start a wash cycle.',
    icon: '🧺',
    category: ChoreCategory.laundry,
  ),
  DefaultChore(
    title: 'Fold the Laundry',
    description: 'Fold clean laundry and sort by owner.',
    icon: '👕',
    category: ChoreCategory.laundry,
  ),
  DefaultChore(
    title: 'Put Away Laundry',
    description: 'Put folded clothes in the correct drawers and closets.',
    icon: '👕',
    category: ChoreCategory.laundry,
  ),

  // Bedroom
  DefaultChore(
    title: 'Make Your Bed',
    description: 'Straighten sheets, fluff pillows, and tuck in blankets.',
    icon: '🛏️',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Clean Your Room',
    description: 'Tidy up, put toys away, and clear the floor.',
    icon: '🏠',
    category: ChoreCategory.cleaning,
  ),

  // Bathroom
  DefaultChore(
    title: 'Clean the Toilet',
    description: 'Scrub the inside of the toilet and wipe down the outside.',
    icon: '🚽',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Clean the Shower',
    description: 'Scrub the shower walls, floor, and clean the drain.',
    icon: '🚿',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Clean the Bathroom Sink',
    description: 'Scrub the sink and wipe down the faucet and counter.',
    icon: '🧼',
    category: ChoreCategory.cleaning,
  ),
  DefaultChore(
    title: 'Wipe the Mirrors',
    description: 'Clean bathroom and bedroom mirrors with glass cleaner.',
    icon: '🪟',
    category: ChoreCategory.cleaning,
  ),

  // Yard & Garden
  DefaultChore(
    title: 'Water the Plants',
    description: 'Water all indoor and outdoor plants as needed.',
    icon: '🌱',
    category: ChoreCategory.other,
  ),
  DefaultChore(
    title: 'Mow the Lawn',
    description: 'Mow the grass in the front and/or back yard.',
    icon: '🌿',
    category: ChoreCategory.other,
  ),
  DefaultChore(
    title: 'Rake Leaves',
    description: 'Rake leaves into piles and bag them for disposal.',
    icon: '🍂',
    category: ChoreCategory.other,
  ),
  DefaultChore(
    title: 'Pull Weeds',
    description: 'Pull weeds from flower beds and garden areas.',
    icon: '🌻',
    category: ChoreCategory.other,
  ),

  // Pets
  DefaultChore(
    title: 'Feed the Dog',
    description: "Fill the dog's food and water bowls.",
    icon: '🐶',
    category: ChoreCategory.petCare,
  ),
  DefaultChore(
    title: 'Walk the Dog',
    description: 'Take the dog for a walk around the neighborhood.',
    icon: '🐶',
    category: ChoreCategory.petCare,
  ),
  DefaultChore(
    title: 'Clean the Litter Box',
    description: 'Scoop the litter box and replace litter as needed.',
    icon: '🐱',
    category: ChoreCategory.petCare,
  ),
  DefaultChore(
    title: 'Feed the Fish',
    description: 'Give the fish the correct amount of food.',
    icon: '🐠',
    category: ChoreCategory.petCare,
  ),
  DefaultChore(
    title: 'Feed the Cat',
    description: "Fill the cat's food and water bowls.",
    icon: '🐱',
    category: ChoreCategory.petCare,
  ),

  // School & Learning
  DefaultChore(
    title: 'Do Homework',
    description: 'Sit down and complete all assigned schoolwork.',
    icon: '📚',
    category: ChoreCategory.other,
  ),
  DefaultChore(
    title: 'Read for 30 Minutes',
    description: 'Choose a book and read quietly for at least 30 minutes.',
    icon: '📚',
    category: ChoreCategory.other,
  ),
  DefaultChore(
    title: 'Pack Your Backpack',
    description: 'Make sure homework, supplies, and lunch are packed for school.',
    icon: '🎒',
    category: ChoreCategory.other,
  ),

  // Getting Ready
  DefaultChore(
    title: 'Brush Your Teeth',
    description: 'Brush teeth for at least two minutes, morning and night.',
    icon: '🪥',
    category: ChoreCategory.other,
  ),
  DefaultChore(
    title: 'Take a Shower',
    description: 'Shower with soap and shampoo, and hang up your towel.',
    icon: '🚿',
    category: ChoreCategory.other,
  ),
  DefaultChore(
    title: 'Brush Your Hair',
    description: 'Brush or comb hair until neat and tidy.',
    icon: '🪮',
    category: ChoreCategory.other,
  ),
  DefaultChore(
    title: 'Get Dressed',
    description: 'Put on clean clothes for the day.',
    icon: '👟',
    category: ChoreCategory.other,
  ),
];
