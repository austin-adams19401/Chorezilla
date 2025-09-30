import 'package:flutter/material.dart';

/// Returns (IconData, Color?) when user taps "Use icon".
Future<(IconData, Color?)?> pickChoreIcon(
  BuildContext context, {
  IconData? initial,
  Color? initialColor,
}) async {
  // Curated categories (safe/common icons so you don't hit unknowns)
  final categories = <String, List<IconData>>{
    'Cleaning': [
      Icons.cleaning_services, Icons.delete_outline, Icons.recycling,
      Icons.wash, Icons.bathtub_outlined, Icons.shower, Icons.kitchen,
      Icons.local_laundry_service, Icons.soap, Icons.countertops,
    ],
    'Kitchen': [
      Icons.local_dining, Icons.restaurant, Icons.dinner_dining, Icons.ramen_dining,
      Icons.local_pizza, Icons.icecream, Icons.flatware, Icons.local_drink,
      Icons.blender, Icons.microwave,
    ],
    'Bedroom': [
      Icons.bed_outlined, Icons.hotel, Icons.chair, Icons.nightlight_outlined,
      Icons.lightbulb, Icons.inventory_2, Icons.home,
    ],
    'School': [
      Icons.school, Icons.menu_book, Icons.book, Icons.calculate,
      Icons.science, Icons.biotech, Icons.assignment,
    ],
    'Pets': [
      Icons.pets, Icons.set_meal, Icons.emoji_nature, Icons.egg_alt,
    ],
    'Outdoors': [
      Icons.grass, Icons.park, Icons.yard, Icons.compost, Icons.terrain, Icons.local_florist,
    ],
    'Tech & Misc': [
      Icons.devices, Icons.smartphone, Icons.tv, Icons.sports_esports,
      Icons.calendar_today, Icons.timer, Icons.schedule, Icons.alarm,
      Icons.task_alt, Icons.check_circle, Icons.stars, Icons.star_border,
      Icons.build, Icons.handyman,
    ],
  };

  // Theme-based swatches + a few accents
  final cs = Theme.of(context).colorScheme;
  final swatches = <Color>[
    cs.primary, cs.secondary, cs.tertiary, cs.inversePrimary,
    Colors.amber.shade600, Colors.red.shade400, Colors.blue.shade400,
    Colors.purple.shade400, Colors.teal.shade400, Colors.brown.shade400,
  ];

  String currentCat = 'Cleaning';
  IconData? selectedIcon = initial ?? categories.values.first.first;
  Color? selectedColor = initialColor ?? cs.onSecondaryContainer;

  return showModalBottomSheet<(IconData, Color?)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: cs.surface,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSB) {
          final icons = categories[currentCat]!;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Choose an icon', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                // Category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.keys.map((k) {
                      final sel = k == currentCat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(k),
                          selected: sel,
                          onSelected: (_) => setSB(() => currentCat = k),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                // Icon grid
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6, mainAxisSpacing: 10, crossAxisSpacing: 10),
                    itemCount: icons.length,
                    itemBuilder: (_, i) {
                      final icon = icons[i];
                      final sel = icon == selectedIcon;
                      return InkWell(
                        onTap: () => setSB(() => selectedIcon = icon),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: sel ? cs.primaryContainer : cs.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? cs.primary : Colors.transparent, width: 2),
                          ),
                          child: Icon(
                            icon,
                            size: 28,
                            // show a little color even before picking swatch
                            color: sel ? cs.onPrimaryContainer : cs.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Color swatches
                Row(
                  children: [
                    Text('Color', style: Theme.of(ctx).textTheme.bodyMedium),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: swatches.map((c) {
                          final sel = selectedColor?.value == c.value;
                          return GestureDetector(
                            onTap: () => setSB(() => selectedColor = c),
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sel ? cs.onPrimary : cs.surface,
                                  width: sel ? 3 : 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Preview
                    CircleAvatar(
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(selectedIcon, color: selectedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, (selectedIcon!, selectedColor)),
                      child: const Text('Use icon'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
