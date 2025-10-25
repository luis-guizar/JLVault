import 'package:flutter/material.dart';

/// A badge widget that indicates premium features
class PremiumBadge extends StatelessWidget {
  final String? text;
  final double? size;
  final Color? color;
  final bool showIcon;

  const PremiumBadge({
    super.key,
    this.text,
    this.size,
    this.color,
    this.showIcon = true,
  });

  const PremiumBadge.small({
    super.key,
    this.text = 'PRO',
    this.color,
    this.showIcon = false,
  }) : size = 12.0;

  const PremiumBadge.large({
    super.key,
    this.text = 'PREMIUM',
    this.color,
    this.showIcon = true,
  }) : size = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.primary;
    final textSize = size ?? 14.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        border: Border.all(color: badgeColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(Icons.star, size: textSize, color: badgeColor),
            const SizedBox(width: 2),
          ],
          Text(
            text ?? 'PREMIUM',
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.bold,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
