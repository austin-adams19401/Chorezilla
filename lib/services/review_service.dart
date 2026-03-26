import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCompletionCountKey = 'chore_completion_count';
const _kReviewPromptedKey = 'review_prompted';
const _kPromptAfter = 10;

class ReviewService {
  ReviewService._();

  /// Call this after each chore completion. Triggers a review prompt
  /// once the user has completed [_kPromptAfter] chores.
  static Future<void> trackCompletionAndMaybePrompt() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyPrompted = prefs.getBool(_kReviewPromptedKey) ?? false;
    if (alreadyPrompted) return;

    final count = (prefs.getInt(_kCompletionCountKey) ?? 0) + 1;
    await prefs.setInt(_kCompletionCountKey, count);

    if (count >= _kPromptAfter) {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setBool(_kReviewPromptedKey, true);
      }
    }
  }
}
