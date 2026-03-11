import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../domain/models/review_model.dart';
import 'rating_stars.dart';

class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.review,
    this.highlight = false,
    this.onPinPressed,
  });

  final ReviewModel review;
  final bool highlight;
  final Future<void> Function(ReviewModel review)? onPinPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: highlight ? tokens.accent.withValues(alpha: 0.08) : tokens.surface0,
        border: Border(
          bottom: BorderSide(color: tokens.borderSoft),
          left: highlight ? BorderSide(color: tokens.accent, width: 2) : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.appName,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RatingStars(rating: review.rating),
                      if (review.author != null && review.author!.isNotEmpty)
                        Text(
                          review.author!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: tokens.textTertiary,
                              ),
                        ),
                      if (review.reviewDate != null && review.reviewDate!.isNotEmpty)
                        Text(
                          review.reviewDate!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: tokens.textMuted,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _displayContent(review.content),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (onPinPressed != null)
              IconButton(
                onPressed: () => onPinPressed!(review),
                icon: Icon(
                  review.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 20,
                  color: review.pinned ? tokens.accent : tokens.textMuted,
                ),
                tooltip: review.pinned ? 'Unpin' : 'Pin',
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show real review text; treat Play Store placeholder "Show review history" as no content.
  static String _displayContent(String content) {
    final t = content.trim();
    if (t.isEmpty) return '(No review text)';
    if (t.toLowerCase() == 'show review history') return '(No review text)';
    return content;
  }
}
