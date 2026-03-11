import 'package:flutter/material.dart';

import '../../config/theme.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.max = 5});

  final int? rating;
  final int max;

  @override
  Widget build(BuildContext context) {
    final value = (rating ?? 0).clamp(0, max);
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(max, (index) {
        final active = index < value;
        return Icon(
          active ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: active ? tokens.accent : tokens.textMuted,
        );
      }),
    );
  }
}
