// Re-export theme components for convenience
export 'colors.dart';
export 'decorations.dart';
export 'typography.dart';
export 'spacing.dart';
export 'timings.dart';

import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'spacing.dart';

/// Main theme configuration for Integrity Studio
/// Exports all theme components for easy access
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        // Colors
        primaryColor: AppColors.blue500,
        scaffoldBackgroundColor: AppColors.backgroundPrimary,
        canvasColor: AppColors.backgroundPrimary,
        cardColor: AppColors.backgroundCard,
        dividerColor: AppColors.borderDefault,

        // Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: AppColors.blue500,
          secondary: AppColors.indigo500,
          tertiary: AppColors.purple500,
          surface: AppColors.backgroundSecondary,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
          onError: Colors.white,
        ),

        // Typography
        textTheme: _textTheme,

        // App Bar
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.backgroundPrimary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTypography.headingSM,
        ),

        // Elevated Button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue500,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            textStyle: AppTypography.buttonText,
          ),
        ),

        // Outlined Button
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            side: const BorderSide(color: AppColors.gray700),
            textStyle: AppTypography.buttonText,
          ),
        ),

        // Text Button
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textLink,
            textStyle: AppTypography.link,
          ),
        ),

        // Input Decoration
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.backgroundSecondary,
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            borderSide: const BorderSide(color: AppColors.gray700),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            borderSide: const BorderSide(color: AppColors.gray700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            borderSide: const BorderSide(color: AppColors.blue500, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          labelStyle: AppTypography.label,
          hintStyle: AppTypography.bodyMD.copyWith(color: AppColors.gray500),
          errorStyle: AppTypography.caption.copyWith(color: AppColors.error),
        ),

        // Card
        cardTheme: CardThemeData(
          color: AppColors.backgroundCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
          margin: EdgeInsets.zero,
        ),

        // Checkbox
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.blue500;
            }
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
          side: const BorderSide(color: AppColors.gray600, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
          ),
        ),

        // Divider
        dividerTheme: const DividerThemeData(
          color: AppColors.gray700,
          thickness: 1,
          space: AppSpacing.lg,
        ),

        // Snackbar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.gray800,
          contentTextStyle: AppTypography.bodyMD,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // Progress Indicator
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.blue500,
          linearTrackColor: AppColors.gray700,
          circularTrackColor: AppColors.gray700,
        ),
      );

  static TextTheme get _textTheme => TextTheme(
        displayLarge: AppTypography.headingXL,
        displayMedium: AppTypography.headingLG,
        displaySmall: AppTypography.headingMD,
        headlineMedium: AppTypography.headingSM,
        titleLarge: AppTypography.headingSM,
        titleMedium: AppTypography.bodyLG,
        titleSmall: AppTypography.label,
        bodyLarge: AppTypography.bodyLG,
        bodyMedium: AppTypography.bodyMD,
        bodySmall: AppTypography.bodySM,
        labelLarge: AppTypography.buttonText,
        labelMedium: AppTypography.label,
        labelSmall: AppTypography.caption,
      );
}
