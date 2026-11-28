
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foodwise_theme.dart';
import '../services/meal_service.dart';
import '../widgets/food_browse_widgets.dart';

class SpinMealScreen extends StatefulWidget {
  const SpinMealScreen({super.key});

  @override
  State<SpinMealScreen> createState() => _SpinMealScreenState();
}

class _SpinMealScreenState extends State<SpinMealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final TextEditingController _budgetController;

  List<FoodWiseMeal> _meals = [];
  List<FoodWiseMeal> _filteredMeals = [];
  List<FoodWiseMeal>? _spinMeals;

  String? _selectedCategory;
  bool _loading = true;
  bool _spinning = false;
  String? _error;
  String? _budgetError;

  double _rotation = 0;

  static const List<Color> _wheelColors = [
    Color(0xFFFFB74D),
    Color(0xFFFF8A65),
    Color(0xFFFFCC80),
    Color(0xFFFF7043),
    Color(0xFFFFAB91),
    Color(0xFFFFD180),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _budgetController = TextEditingController();

    _loadMeals();
  }

  @override
  void dispose() {
    _controller.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadMeals() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    // Load all published and available meals from Strapi.
    final meals = await FoodWiseMealService.fetchAvailableMeals();

    if (!mounted) return;

    setState(() {
      _meals = meals;
      _loading = false;
    });

    _applyFilters();
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = e.toString();
    });
  }
}

  List<String> get _categories {
    final categories = _meals
        .map((meal) => meal.category)
        .where((category) =>
            category.isNotEmpty && category != 'Not specified')
        .toSet()
        .toList()
      ..sort();

    return categories;
  }

void _applyFilters() {
  final budgetText = _budgetController.text.trim();
  final budget = budgetText.isEmpty
      ? null
      : double.tryParse(budgetText);

  // Validate the budget input.
  if (budgetText.isNotEmpty && (budget == null || budget <= 0)) {
    setState(() {
      _budgetError = 'Please enter a valid budget greater than zero.';
    });
    return;
  }

  setState(() {
    _budgetError = null;
  });

  // Start with all meals that passed the existing
  // availability and saved dietary-safety filtering.
  var filtered = List<FoodWiseMeal>.from(_meals);

  // Show meals within the entered budget.
  if (budget != null) {
    filtered = filtered.where((meal) {
      return meal.price <= budget;
    }).toList();
  }

  // Apply category filtering.
  if (_selectedCategory != null) {
    filtered = filtered.where((meal) {
      return meal.category == _selectedCategory;
    }).toList();
  }

  setState(() {
    _filteredMeals = filtered;
  });
}

Future<void> _spinWheel() async {
  if (_spinning || _filteredMeals.isEmpty) return;

  // Keep a snapshot so the selected meal cannot change during the spin.
  final mealsAtSpin = List<FoodWiseMeal>.unmodifiable(_filteredMeals);

  final random = math.Random();
  final selectedIndex = random.nextInt(mealsAtSpin.length);
  final selectedMeal = mealsAtSpin[selectedIndex];

  final segmentAngle = (2 * math.pi) / mealsAtSpin.length;

  // Calculate the angle that places the selected slice
  // exactly under the pointer at the top.
  final currentNormalized = _rotation % (2 * math.pi);
  final desiredNormalized =
      (-(selectedIndex + 0.5) * segmentAngle) % (2 * math.pi);

  final extraRotation =
      (desiredNormalized - currentNormalized + 2 * math.pi) %
          (2 * math.pi);

  // Add five complete spins before reaching the selected slice.
  final targetRotation =
      _rotation + (2 * math.pi * 5) + extraRotation;

  setState(() {
    _spinning = true;
    _spinMeals = mealsAtSpin;
  });

  _controller.reset();

  final animation = Tween<double>(
    begin: _rotation,
    end: targetRotation,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ),
  );

  void updateRotation() {
    if (mounted) {
      setState(() {
        _rotation = animation.value;
      });
    }
  }

  animation.addListener(updateRotation);

  await _controller.forward();

  animation.removeListener(updateRotation);

  if (!mounted) return;

  setState(() {
    _rotation = targetRotation;
    _spinning = false;
  });

  // Show the exact same meal selected before the animation.
  await _showResultDialog(selectedMeal);
}

  Future<void> _showResultDialog(FoodWiseMeal meal) async {
    final spinAgain = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF5),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'YOUR MEAL IS SELECTED!',
                            style: TextStyle(
                              color: FoodWiseColors.deepOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                          ? Image.network(
                              meal.imageUrl!,
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      meal.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: FoodWiseColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱${meal.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: FoodWiseColors.deepOrange,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _resultDetail(Icons.category_outlined, 'Category', meal.category),
                    const SizedBox(height: 7),
                    _resultDetail(Icons.storefront_outlined, 'Business', meal.business),
                    if (meal.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        meal.description,
                        style: const TextStyle(
                          color: FoodWiseColors.charcoal,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Please confirm ingredients and possible cross-contact with the seller. Food listings are not a guarantee of allergen safety.',
                      style: TextStyle(
                        color: FoodWiseColors.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('SPIN AGAIN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FoodWiseColors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FoodWiseColors.deepOrange,
                          side: const BorderSide(color: FoodWiseColors.deepOrange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text('DONE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (spinAgain == true && mounted) {
      await _spinWheel();
    }
  }

  Widget _resultDetail(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: FoodWiseColors.deepOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              color: FoodWiseColors.charcoal,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCategoryPicker() async {
    final categories = <String?>[null, ..._categories];

    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        String? temporarySelection = _selectedCategory;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFAF5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8C9BD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Choose a meal category',
                            style: TextStyle(
                              color: FoodWiseColors.charcoal,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: categories.map((category) {
                            final isSelected = temporarySelection == category;
                            final title = category ?? 'All Categories';
                            final icon = category == null
                                ? Icons.grid_view_rounded
                                : _categoryIcon(category);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: isSelected
                                    ? const Color(0xFFFFE8D8)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setSheetState(
                                    () => temporarySelection = category,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(icon, color: FoodWiseColors.deepOrange),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              color: FoodWiseColors.charcoal,
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: FoodWiseColors.deepOrange,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          temporarySelection ?? '__ALL__',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FoodWiseColors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text('APPLY CATEGORY'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedCategory = selected == '__ALL__' ? null : selected;
    });
    _applyFilters();
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();
    if (value.contains('rice')) return Icons.rice_bowl_rounded;
    if (value.contains('noodle')) return Icons.ramen_dining_rounded;
    if (value.contains('beverage') || value.contains('drink')) {
      return Icons.local_cafe_rounded;
    }
    if (value.contains('dessert')) return Icons.cake_rounded;
    if (value.contains('snack')) return Icons.fastfood_rounded;
    return Icons.restaurant_menu_rounded;
  }

  Widget _buildWheel() {
    if (_filteredMeals.isEmpty) {
      return const BrowseState(
        icon: Icons.restaurant_menu_rounded,
        title: 'No meals available',
        message:
            'Try changing your budget or category to find more meals.',
      );
    }

    return Column(
      children: [
        SizedBox(
          width: 310,
          height: 310,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _rotation,
                child: CustomPaint(
                  size: const Size(300, 300),
                  painter: _MealWheelPainter(
                    meals: _spinning ? (_spinMeals ?? _filteredMeals) : _filteredMeals,
                    colors: _wheelColors,
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 48,
                  color: FoodWiseColors.charcoal,
                ),
              ),
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FoodWiseColors.deepOrange,
                    width: 4,
                  ),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: FoodWiseColors.deepOrange,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _spinning ? null : _spinWheel,
            icon: const Icon(Icons.casino_rounded),
            label: Text(
              _spinning ? 'Spinning...' : 'SPIN NOW',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodWiseColors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: FoodWiseColors.paleOrange,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.restaurant,
        size: 55,
        color: FoodWiseColors.deepOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FoodWisePage(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Spin the Meal',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: FoodWiseColors.charcoal,
                      ),
                    ),
                    BrowseState(
                      icon: Icons.error_outline,
                      title: 'Unable to load meals',
                      message: _error!,
                      actionLabel: 'Try Again',
                      onAction: _loadMeals,
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Spin the Meal',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: FoodWiseColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Let FoodWise decide what you should eat!',
                      style: TextStyle(
                        color: FoodWiseColors.muted,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Budget filter
                    TextField(
                      controller: _budgetController,
                      enabled: !_spinning,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Budget (₱)',
                        hintText: 'Example: 100',
                        errorText: _budgetError,
                        prefixIcon:
                            const Icon(Icons.payments_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onChanged: (_) => _applyFilters(),
                    ),
                    const SizedBox(height: 14),

                    // Custom category selector
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _spinning ? null : _showCategoryPicker,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Meal Category',
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            color: FoodWiseColors.deepOrange,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 17,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: FoodWiseColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: FoodWiseColors.deepOrange,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedCategory ?? 'All Categories',
                                style: const TextStyle(
                                  color: FoodWiseColors.charcoal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: FoodWiseColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        '${_filteredMeals.length} meals available',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: FoodWiseColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildWheel(),
                  ],
                ),
    );
  }
}

class _MealWheelPainter extends CustomPainter {
  final List<FoodWiseMeal> meals;
  final List<Color> colors;

  _MealWheelPainter({
    required this.meals,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (meals.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = (2 * math.pi) / meals.length;

    for (var i = 0; i < meals.length; i++) {
      final startAngle = -math.pi / 2 + i * segmentAngle;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      final textAngle = startAngle + segmentAngle / 2;
      final textRadius = radius * 0.68;

      final textPosition = Offset(
        center.dx + math.cos(textAngle) * textRadius,
        center.dy + math.sin(textAngle) * textRadius,
      );

      final text = meals[i].name.length > 15
          ? '${meals[i].name.substring(0, 13)}...'
          : meals[i].name;

      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: FoodWiseColors.charcoal,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 85);

      canvas.save();
      canvas.translate(textPosition.dx, textPosition.dy);
      canvas.rotate(textAngle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = FoodWiseColors.deepOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant _MealWheelPainter oldDelegate) {
    return oldDelegate.meals != meals;
  }
}
