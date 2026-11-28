import 'package:flutter/material.dart';

import '../models/food.dart';
import '../services/student_food_controller.dart';
import '../foodwise_theme.dart';
import 'dart:async';

/// Shared control so card and detail screen use the same save/error behavior.
class FavoriteButton extends StatelessWidget {
  final StudentFoodController controller;
  final Food food;
  const FavoriteButton({
    super.key,
    required this.controller,
    required this.food,
  });

  @override
  Widget build(BuildContext context) {
    final saved = controller.isFavorite(food);
    final pending = controller.favoritePending(food);
    return IconButton(
      tooltip: !controller.hasDocumentId(food)
          ? 'This meal cannot be saved yet'
          : pending
          ? 'Saving changes'
          : controller.favoritesLoading
          ? 'Loading favorites'
          : controller.favoritesFailed
          ? 'Favorites unavailable'
          : saved
          ? 'Remove from favorites'
          : 'Add to favorites',
      onPressed: controller.canChangeFavorite(food)
          ? () => toggleFavoriteWithFeedback(context, controller, food)
          : null,
      icon: pending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FoodWiseColors.deepOrange,
              ),
            )
          : Icon(
              saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: controller.canChangeFavorite(food)
                  ? (saved
                        ? FoodWiseColors.deepOrange
                        : FoodWiseColors.charcoal)
                  : null,
            ),
    );
  }
}

Future<void> toggleFavoriteWithFeedback(
  BuildContext context,
  StudentFoodController controller,
  Food food,
) async {
  final wasSaved = controller.isFavorite(food);
  // Capture the messenger first: removing a saved card can unmount its context.
  final messenger = ScaffoldMessenger.of(context);
  try {
    final changed = await controller.setFavorite(food, !wasSaved);
    if (!changed || !controller.active || !messenger.mounted) return;
    messenger.clearSnackBars();
    Timer? autoDismissTimer;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        wasSaved ? 'Removed from Favorites.' : 'Added to Favorites.',
      ),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          autoDismissTimer?.cancel();

          if (!controller.active || !messenger.mounted) return;

          try {
            if (controller.isFavorite(food) == wasSaved) return;

            final restored = await controller.setFavorite(food, wasSaved);

            if (!controller.active || !messenger.mounted) return;

            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  restored
                      ? 'Change undone.'
                      : 'Could not undo right now. Please try again.',
                ),
              ),
            );
          } catch (_) {
            if (controller.active && messenger.mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Could not undo. Please try again.'),
                ),
              );
            }
          }
        },
      ),
    ),
  );

  autoDismissTimer = Timer(const Duration(seconds: 3), () {
    if (messenger.mounted) {
      messenger.hideCurrentSnackBar();
    }
  });
  } catch (_) {
    if (controller.active && messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update favorites. Check your connection and try again.',
          ),
        ),
      );
    }
  }
}
