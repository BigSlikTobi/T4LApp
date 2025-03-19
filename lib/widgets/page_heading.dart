import 'package:flutter/material.dart';

class PageHeading extends StatelessWidget {
  final String title;
  final double fontSize;
  final Color? textColor;

  const PageHeading({
    super.key,
    required this.title,
    this.fontSize = 32.0,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: theme.textTheme.headlineLarge?.copyWith(
          fontSize: fontSize,
          color: textColor ?? theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
