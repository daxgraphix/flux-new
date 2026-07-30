import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 2),
              ),
              child: Icon(
                icon,
                size: 72,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title.toUpperCase(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  buttonLabel!.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
