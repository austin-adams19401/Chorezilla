class DefaultChore {
  final String title;
  final String description;
  final String icon;

  const DefaultChore({
    required this.title,
    required this.description,
    required this.icon,
  });
}

const List<DefaultChore> kDefaultChores = [
  // Dishes & Kitchen
  DefaultChore(
    title: 'Do the Dishes',
    description: 'Wash, rinse, and dry all dishes in the sink.',
    icon: '🍽️',
  ),
  DefaultChore(
    title: 'Load the Dishwasher',
    description: 'Rinse dishes and load them neatly into the dishwasher.',
    icon: '🍽️',
  ),
  DefaultChore(
    title: 'Unload the Dishwasher',
    description: 'Put away all clean dishes and utensils from the dishwasher.',
    icon: '🍽️',
  ),
  DefaultChore(
    title: 'Wipe Down Counters',
    description: 'Wipe kitchen and bathroom counters clean with a damp cloth.',
    icon: '🧽',
  ),
  DefaultChore(
    title: 'Wipe the Stove',
    description: 'Wipe down burners and stove surface after cooking.',
    icon: '🍳',
  ),
  DefaultChore(
    title: 'Clean the Microwave',
    description: 'Wipe inside and outside of the microwave until clean.',
    icon: '🧊',
  ),
  DefaultChore(
    title: 'Set the Table',
    description: 'Place plates, silverware, and cups for each person.',
    icon: '🍴',
  ),
  DefaultChore(
    title: 'Clear the Table',
    description: 'Remove dishes, wipe the table, and push in chairs.',
    icon: '🍴',
  ),

  // Floors & General Cleaning
  DefaultChore(
    title: 'Sweep the Floor',
    description: 'Sweep floors and collect dirt into the dustpan.',
    icon: '🧹',
  ),
  DefaultChore(
    title: 'Mop the Floor',
    description: 'Mop hard floors until clean and dry.',
    icon: '🪣',
  ),
  DefaultChore(
    title: 'Vacuum',
    description: 'Vacuum all carpeted areas in the assigned rooms.',
    icon: '🧹',
  ),

  // Trash
  DefaultChore(
    title: 'Take Out the Trash',
    description: 'Replace trash bags and take bins to the designated area.',
    icon: '🗑️',
  ),
  DefaultChore(
    title: 'Take Out the Recycling',
    description: 'Sort and take recycling to the bin outside.',
    icon: '♻️',
  ),

  // Laundry
  DefaultChore(
    title: 'Start the Laundry',
    description: 'Sort clothes, add detergent, and start a wash cycle.',
    icon: '🧺',
  ),
  DefaultChore(
    title: 'Fold the Laundry',
    description: 'Fold clean laundry and sort by owner.',
    icon: '👕',
  ),
  DefaultChore(
    title: 'Put Away Laundry',
    description: 'Put folded clothes in the correct drawers and closets.',
    icon: '👕',
  ),

  // Bedroom
  DefaultChore(
    title: 'Make Your Bed',
    description: 'Straighten sheets, fluff pillows, and tuck in blankets.',
    icon: '🛏️',
  ),
  DefaultChore(
    title: 'Clean Your Room',
    description: 'Tidy up, put toys away, and clear the floor.',
    icon: '🏠',
  ),

  // Bathroom
  DefaultChore(
    title: 'Clean the Toilet',
    description: 'Scrub the inside of the toilet and wipe down the outside.',
    icon: '🚽',
  ),
  DefaultChore(
    title: 'Clean the Shower',
    description: 'Scrub the shower walls, floor, and clean the drain.',
    icon: '🚿',
  ),
  DefaultChore(
    title: 'Clean the Bathroom Sink',
    description: 'Scrub the sink and wipe down the faucet and counter.',
    icon: '🧼',
  ),
  DefaultChore(
    title: 'Wipe the Mirrors',
    description: 'Clean bathroom and bedroom mirrors with glass cleaner.',
    icon: '🪟',
  ),

  // Yard & Garden
  DefaultChore(
    title: 'Water the Plants',
    description: 'Water all indoor and outdoor plants as needed.',
    icon: '🌱',
  ),
  DefaultChore(
    title: 'Mow the Lawn',
    description: 'Mow the grass in the front and/or back yard.',
    icon: '🌿',
  ),
  DefaultChore(
    title: 'Rake Leaves',
    description: 'Rake leaves into piles and bag them for disposal.',
    icon: '🍂',
  ),
  DefaultChore(
    title: 'Pull Weeds',
    description: 'Pull weeds from flower beds and garden areas.',
    icon: '🌻',
  ),

  // Pets
  DefaultChore(
    title: 'Feed the Dog',
    description: "Fill the dog's food and water bowls.",
    icon: '🐶',
  ),
  DefaultChore(
    title: 'Walk the Dog',
    description: 'Take the dog for a walk around the neighborhood.',
    icon: '🐶',
  ),
  DefaultChore(
    title: 'Clean the Litter Box',
    description: 'Scoop the litter box and replace litter as needed.',
    icon: '🐱',
  ),
  DefaultChore(
    title: 'Feed the Fish',
    description: 'Give the fish the correct amount of food.',
    icon: '🐠',
  ),
  DefaultChore(
    title: 'Feed the Cat',
    description: "Fill the cat's food and water bowls.",
    icon: '🐱',
  ),

  // School & Learning
  DefaultChore(
    title: 'Do Homework',
    description: 'Sit down and complete all assigned schoolwork.',
    icon: '📚',
  ),
  DefaultChore(
    title: 'Read for 30 Minutes',
    description: 'Choose a book and read quietly for at least 30 minutes.',
    icon: '📚',
  ),
  DefaultChore(
    title: 'Pack Your Backpack',
    description: 'Make sure homework, supplies, and lunch are packed for school.',
    icon: '🎒',
  ),

  // Getting Ready
  DefaultChore(
    title: 'Brush Your Teeth',
    description: 'Brush teeth for at least two minutes, morning and night.',
    icon: '🪥',
  ),
  DefaultChore(
    title: 'Take a Shower',
    description: 'Shower with soap and shampoo, and hang up your towel.',
    icon: '🚿',
  ),
  DefaultChore(
    title: 'Brush Your Hair',
    description: 'Brush or comb hair until neat and tidy.',
    icon: '🪮',
  ),
  DefaultChore(
    title: 'Get Dressed',
    description: 'Put on clean clothes for the day.',
    icon: '👟',
  ),
];
