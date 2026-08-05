import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppStyles {
  // Padding & Margins
  static const double padXs = 4.0;
  static const double padSm = 8.0;
  static const double padMd = 16.0;
  static const double padLg = 24.0;
  static const double padXl = 32.0;

  static const EdgeInsets defaultPadding = EdgeInsets.all(padMd);
  static const EdgeInsets defaultScreenPadding = EdgeInsets.all(padLg);

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;

  static final BorderRadius defaultRadius = BorderRadius.circular(radiusMd);
  static final BorderRadius cardRadius = BorderRadius.circular(radiusLg);
  static final BorderRadius pillRadius = BorderRadius.circular(100.0);

  // Text Styles (Assuming use of Material3 defaults, just standardizing a few headers)
  static const TextStyle headerWhite = TextStyle(
    color: Colors.white,
    fontSize: 26,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle subtitleWhite = TextStyle(
    color: Colors.white70,
    fontSize: 14,
  );

  static const TextStyle cardTitle = TextStyle(
    color: AppColors.primaryDark,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: Colors.black54, // Or Colors.grey.shade700
    fontSize: 13,
  );

  // Shadows
  static final List<BoxShadow> defaultShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> heavyShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
