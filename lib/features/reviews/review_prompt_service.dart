import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

/// Android's native In-App Review API (spec Section 3b) — triggered only
/// after a positive moment (hitting a 7-day streak), never randomly.
///
/// The API is subject to a Google-imposed display quota and may decline
/// to show anything even when requested; there's no way to detect that
/// and no custom fallback dialog is built for it — asking again just
/// silently does nothing that time, which is the documented behavior to
/// design around, not a bug to work around.
class ReviewPromptService {
  ReviewPromptService({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  Future<void> maybePromptAfterStreakMilestone(int currentStreak) async {
    if (currentStreak != 7) return;
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.requestReview();
    }
  }
}

final reviewPromptServiceProvider = Provider<ReviewPromptService>(
  (ref) => ReviewPromptService(),
);
