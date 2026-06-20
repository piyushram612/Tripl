import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/customization_provider.dart';
import '../../providers/category_provider.dart';

class ManageItemsSheet extends ConsumerStatefulWidget {
  final String title;
  final String itemLabel; // e.g. "Category", "Payment Source"
  final String hintText;  // e.g. "Source name (e.g. Cash)"
  final List<String> items;
  final ScrollController? scrollController;

  final Future<void> Function(String name) onAdd;
  final Future<void> Function(String name) onDelete;
  final Future<void> Function(String oldName, String newName) onUpdate;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  const ManageItemsSheet({
    super.key,
    required this.title,
    required this.itemLabel,
    required this.hintText,
    required this.items,
    this.scrollController,
    required this.onAdd,
    required this.onDelete,
    required this.onUpdate,
    required this.onReorder,
  });

  @override
  ConsumerState<ManageItemsSheet> createState() => _ManageItemsSheetState();
}

class _ManageItemsSheetState extends ConsumerState<ManageItemsSheet> {
  static const Map<String, Color> _intentColors = {
    CategoryIntent.essential: Color(0xFF4EDEA3),
    CategoryIntent.joyful: Color(0xFF9FB6DF),
    CategoryIntent.avoidable: Color(0xFFFFB5B5),
    CategoryIntent.investments: Color(0xFF8B5CF6),
  };

  static const Map<String, IconData> _intentIcons = {
    CategoryIntent.essential: Icons.shield_outlined,
    CategoryIntent.joyful: Icons.favorite_outline_rounded,
    CategoryIntent.avoidable: Icons.do_not_disturb_alt_outlined,
    CategoryIntent.investments: Icons.trending_up_outlined,
  };

  static const List<Color> _customizerColors = [
    Color(0xFF4EDEA3), // Mint Green
    Color(0xFF10B981), // Emerald Green
    Color(0xFF22C55E), // Forest Green
    Color(0xFF14B8A6), // Teal
    Color(0xFF06B6D4), // Sky Cyan
    Color(0xFF38BDF8), // Light Cyan
    Color(0xFF9FB6DF), // Slate Blue
    Color(0xFF3A41C7), // Deep Violet
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Royal Purple
    Color(0xFFD946EF), // Orchid Pink
    Color(0xFFEC4899), // Pink
    Color(0xFFFDA4AF), // Rose Gold
    Color(0xFFF43F5E), // Coral Red
    Color(0xFFEF4444), // Crimson Red
    Color(0xFFF97316), // Rust Orange
    Color(0xFFF59E0B), // Sunset Amber
    Color(0xFFEAB308), // Goldenrod Yellow
    Color(0xFF84CC16), // Lime Green
    Color(0xFFB45309), // Bronze
    Color(0xFF9CA3AF), // Cool Grey
    Color(0xFF6B7280), // Muted Slate
  ];

  static const List<IconData> _customizerIcons = [
    // Food & Drink
    Icons.local_cafe_outlined,
    Icons.restaurant_outlined,
    Icons.fastfood_outlined,
    Icons.lunch_dining_outlined,
    Icons.local_pizza_outlined,
    Icons.icecream_outlined,
    Icons.liquor_outlined,
    
    // Transport & Travel
    Icons.directions_transit_filled_outlined,
    Icons.directions_car_filled_outlined,
    Icons.flight_outlined,
    Icons.pedal_bike_outlined,
    Icons.directions_boat_outlined,
    Icons.luggage_outlined,

    // Shopping & Fashion
    Icons.local_grocery_store_outlined,
    Icons.local_mall_outlined,
    Icons.shopping_bag_outlined,
    Icons.checkroom_outlined,
    Icons.watch_outlined,

    // Bills & Utilities
    Icons.bolt_outlined,
    Icons.water_drop_outlined,
    Icons.phone_android_outlined,
    Icons.wifi_rounded,
    Icons.home_outlined,

    // Health, Care & Fitness
    Icons.local_hospital_outlined,
    Icons.medication_outlined,
    Icons.fitness_center_outlined,
    Icons.spa_outlined,
    Icons.pets_outlined,

    // Entertainment, Hobby & Gifts
    Icons.subscriptions_outlined,
    Icons.sports_esports_outlined,
    Icons.music_note_outlined,
    Icons.movie_outlined,
    Icons.palette_outlined,
    Icons.camera_alt_outlined,
    Icons.card_giftcard_outlined,
    Icons.celebration_outlined,

    // Education, Work & Other
    Icons.school_outlined,
    Icons.work_outline_rounded,
    Icons.payments_outlined,
    Icons.handyman_outlined,
    Icons.star_outline_rounded,
    Icons.favorite_outline_rounded,
  ];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isReordering = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showEditSheet(BuildContext context, String item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditItemSheet(
          itemName: item,
          itemLabel: widget.itemLabel,
          customizerColors: _customizerColors,
          customizerIcons: _customizerIcons,
          intentColors: _intentColors,
          intentIcons: _intentIcons,
          onUpdate: widget.onUpdate,
          onDelete: widget.onDelete,
        );
      },
    );
  }

  Widget _buildItemsList(BuildContext context, {ScrollController? scrollController}) {
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text(
          'No custom ${widget.itemLabel.toLowerCase()}s active. Add one below!',
          style: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
        ),
      );
    }
    
    if (_isReordering) {
      return ReorderableListView(
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        onReorder: (oldIndex, newIndex) async {
          await widget.onReorder(oldIndex, newIndex);
        },
        children: [
          for (int index = 0; index < widget.items.length; index++)
            ListTile(
              key: ValueKey(widget.items[index]),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              tileColor: TallyTapTheme.obsidianCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: TallyTapTheme.borderGreen, width: 0.5),
              ),
              leading: const Icon(Icons.drag_handle_rounded, color: TallyTapTheme.primaryMint, size: 20),
              title: Text(
                widget.items[index],
                style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              trailing: Container(
                margin: const EdgeInsets.only(bottom: 2),
                height: 24,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: TallyTapTheme.textGray, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      );
    }

    final wrapContent = Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: widget.items.map((item) {
        final color = widget.itemLabel == 'Category'
            ? TallyTapTheme.getColorForCategory(item)
            : TallyTapTheme.getColorForSource(item);
        final icon = widget.itemLabel == 'Category'
            ? TallyTapTheme.getIconForCategory(item)
            : null;
        return InputChip(
          avatar: icon != null
              ? Icon(
                  icon,
                  color: color,
                  size: 14,
                )
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
          label: Text(
            item,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: TallyTapTheme.textLight,
            ),
          ),
          backgroundColor: TallyTapTheme.obsidianCard,
          selectedColor: TallyTapTheme.primaryMint,
          checkmarkColor: TallyTapTheme.obsidianBg,
          onPressed: () {
            _showEditSheet(context, item);
          },
          deleteIcon: const Icon(
            Icons.close_rounded,
            color: TallyTapTheme.primaryMint,
            size: 14,
          ),
          onDeleted: () async {
            await widget.onDelete(item);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted ${widget.itemLabel.toLowerCase()}: $item'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
            side: BorderSide(
              color: color.withOpacity(0.5),
              width: 1.0,
            ),
          ),
        );
      }).toList(),
    );

    // Scrollable container for the active items list.
    // Uses the DraggableScrollableSheet's controller so dragging up expands
    // the sheet first, then scrolls content once fully expanded.
    return SingleChildScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: wrapContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customizationProvider); // Dynamic UI updates
    final hasScrollController = widget.scrollController != null;

    // Shared header widgets — no drag handle pill here; it lives in the parent sheet
    Widget buildHeader() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: TallyTapTheme.primaryMint,
                letterSpacing: -0.5,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isReordering ? Icons.grid_view_rounded : Icons.swap_vert_rounded,
                    color: _isReordering ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _isReordering = !_isReordering;
                      _controller.clear();
                      _focusNode.unfocus();
                    });
                  },
                  tooltip: _isReordering ? 'Grid View' : 'Reorder Items',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _isReordering
              ? 'REORDER ${widget.itemLabel.toUpperCase()}S (DRAG TO SORT)'
              : 'ACTIVE ${widget.itemLabel.toUpperCase()}S (TAP TO EDIT, \'X\' TO DELETE)',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: TallyTapTheme.textGray,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    Widget buildAddRow() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'ADD NEW ${widget.itemLabel.toUpperCase()}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: TallyTapTheme.textGray,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                  filled: true,
                  fillColor: TallyTapTheme.obsidianCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () async {
                final text = _controller.text.trim();
                if (text.isEmpty) return;
                await widget.onAdd(text);
                _controller.clear();
                _focusNode.unfocus();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${widget.itemLabel.toLowerCase()}: $text'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.add_circle_rounded,
                color: TallyTapTheme.primaryMint,
                size: 36,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );

    // When inside a DraggableScrollableSheet we get a finite height — use a
    // Column with Expanded so the items list fills remaining space and the
    // add-row stays pinned at the bottom without overflowing.
    if (hasScrollController) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildHeader(),
          Expanded(child: _buildItemsList(context, scrollController: widget.scrollController)),
            if (!_isReordering) buildAddRow(),
          ],
        ),
      );
    }

    // No scroll controller — sheet sizes to content, wrap in scroll view.
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildHeader(),
            _buildItemsList(context),            if (!_isReordering) buildAddRow(),
          ],
        ),
      ),
    );
  }
}

class _EditItemSheet extends ConsumerStatefulWidget {
  final String itemName;
  final String itemLabel;
  final List<Color> customizerColors;
  final List<IconData> customizerIcons;
  final Map<String, Color> intentColors;
  final Map<String, IconData> intentIcons;
  final Future<void> Function(String oldName, String newName) onUpdate;
  final Future<void> Function(String name) onDelete;

  const _EditItemSheet({
    required this.itemName,
    required this.itemLabel,
    required this.customizerColors,
    required this.customizerIcons,
    required this.intentColors,
    required this.intentIcons,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  ConsumerState<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<_EditItemSheet> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late String _currentItemName;

  @override
  void initState() {
    super.initState();
    _currentItemName = widget.itemName;
    _controller = TextEditingController(text: widget.itemName);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customizationProvider); // Dynamic UI updates
    
    final isCategory = widget.itemLabel == 'Category';
    final currentColor = isCategory
        ? TallyTapTheme.getColorForCategory(_currentItemName)
        : TallyTapTheme.getColorForSource(_currentItemName);
        
    final currentIcon = isCategory
        ? TallyTapTheme.getIconForCategory(_currentItemName)
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: TallyTapTheme.obsidianBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TallyTapTheme.borderGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Configure $_currentItemName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.primaryMint,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Rename input row
            const Text(
              'RENAME ITEM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: TallyTapTheme.textGray,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter new name',
                      hintStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                      filled: true,
                      fillColor: TallyTapTheme.obsidianCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () async {
                    final text = _controller.text.trim();
                    if (text.isEmpty || text == _currentItemName) return;

                    final oldName = _currentItemName;
                    await widget.onUpdate(oldName, text);
                    setState(() {
                      _currentItemName = text;
                    });
                    _focusNode.unfocus();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Renamed "$oldName" to "$text"'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    color: TallyTapTheme.primaryMint,
                    size: 36,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Color customizer
            const Text(
              'CUSTOMIZE COLOR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: TallyTapTheme.textGray,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 84,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: widget.customizerColors.length,
                itemBuilder: (context, idx) {
                  final color = widget.customizerColors[idx];
                  final isSelected = currentColor.value == color.value;
                  return GestureDetector(
                    onTap: () async {
                      if (isCategory) {
                        await ref.read(customizationProvider.notifier).updateCategoryColor(_currentItemName, color);
                      } else {
                        await ref.read(customizationProvider.notifier).updateSourceColor(_currentItemName, color);
                      }
                      setState(() {});
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.0,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, spreadRadius: 1),
                        ] : null,
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, color: TallyTapTheme.obsidianBg, size: 16) : null,
                    ),
                  );
                },
              ),
            ),
            
            if (isCategory) ...[
              const SizedBox(height: 24),
              
              // Icon customizer
              const Text(
                'CUSTOMIZE ICON',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: TallyTapTheme.textGray,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: widget.customizerIcons.length,
                  itemBuilder: (context, idx) {
                    final icon = widget.customizerIcons[idx];
                    final isSelected = currentIcon == icon;
                    return GestureDetector(
                      onTap: () async {
                        await ref.read(customizationProvider.notifier).updateCategoryIcon(_currentItemName, icon);
                        setState(() {});
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.obsidianCard,
                          border: Border.all(
                            color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight,
                          size: 18,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // Intent customizer
              const Text(
                'CUSTOMIZE SPENDING INTENT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: TallyTapTheme.textGray,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: CategoryIntent.all.map((intent) {
                  final intents = ref.watch(categoryIntentsProvider);
                  final currentIntent = intents[_currentItemName] ?? CategoryIntent.essential;
                  final isSelected = currentIntent == intent;
                  
                  final color = widget.intentColors[intent] ?? TallyTapTheme.primaryMint;
                  final icon = widget.intentIcons[intent] ?? Icons.shield_outlined;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await ref.read(categoryIntentsProvider.notifier).updateIntent(_currentItemName, intent);
                        setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.15) : TallyTapTheme.obsidianCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color.withOpacity(0.5) : TallyTapTheme.borderGreen,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? color : TallyTapTheme.textGray,
                              size: 16,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              intent,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                color: isSelected ? color : TallyTapTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Visibility customizer
              const Text(
                'CUSTOMIZE VISIBILITY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: TallyTapTheme.textGray,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: CategoryVisibility.all.map((vis) {
                  final visibilities = ref.watch(categoryVisibilityProvider);
                  final currentVis = visibilities[_currentItemName] ?? CategoryVisibility.expense;
                  final isSelected = currentVis == vis;
                  
                  final color = isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textLight;
                  final icon = vis == CategoryVisibility.expense 
                      ? Icons.arrow_upward_rounded 
                      : (vis == CategoryVisibility.income ? Icons.arrow_downward_rounded : Icons.swap_vert_rounded);
                  
                  final label = vis == CategoryVisibility.expense ? 'Expense' : (vis == CategoryVisibility.income ? 'Income' : 'Both');
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await ref.read(categoryVisibilityProvider.notifier).updateVisibility(_currentItemName, vis);
                        setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.15) : TallyTapTheme.obsidianCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color.withOpacity(0.5) : TallyTapTheme.borderGreen,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? color : TallyTapTheme.textGray,
                              size: 16,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                color: isSelected ? color : TallyTapTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            const SizedBox(height: 32),
            const Divider(color: TallyTapTheme.borderGreen, height: 1, thickness: 0.5),
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final itemToDelete = _currentItemName;
                      Navigator.pop(context);
                      await widget.onDelete(itemToDelete);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted ${widget.itemLabel.toLowerCase()}: $itemToDelete'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TallyTapTheme.primaryMint,
                      foregroundColor: TallyTapTheme.obsidianBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
