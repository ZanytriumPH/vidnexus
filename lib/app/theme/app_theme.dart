import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.summarySectionTitle,
    required this.summaryContentBody,
    required this.primaryActionButtonLabel,
  });

  final TextStyle summarySectionTitle;
  final TextStyle summaryContentBody;
  final TextStyle primaryActionButtonLabel;

  @override
  AppTextStyles copyWith({
    TextStyle? summarySectionTitle,
    TextStyle? summaryContentBody,
    TextStyle? primaryActionButtonLabel,
  }) {
    return AppTextStyles(
      summarySectionTitle: summarySectionTitle ?? this.summarySectionTitle,
      summaryContentBody: summaryContentBody ?? this.summaryContentBody,
      primaryActionButtonLabel:
          primaryActionButtonLabel ?? this.primaryActionButtonLabel,
    );
  }

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) {
      return this;
    }

    return AppTextStyles(
      summarySectionTitle: TextStyle.lerp(
            summarySectionTitle,
            other.summarySectionTitle,
            t,
          ) ??
          summarySectionTitle,
      summaryContentBody: TextStyle.lerp(
            summaryContentBody,
            other.summaryContentBody,
            t,
          ) ??
          summaryContentBody,
      primaryActionButtonLabel: TextStyle.lerp(
            primaryActionButtonLabel,
            other.primaryActionButtonLabel,
            t,
          ) ??
          primaryActionButtonLabel,
    );
  }
}

class AppMessageStyles extends ThemeExtension<AppMessageStyles> {
  const AppMessageStyles({
    required this.draftSurface,
    required this.finalSurface,
    required this.systemSurface,
    required this.userSurface,
    required this.messageSpacing,
    required this.draftRadius,
    required this.chatBubbleRadius,
    required this.draftPadding,
    required this.finalPadding,
    required this.bubblePadding,
  });

  final Color draftSurface;
  final Color finalSurface;
  final Color systemSurface;
  final Color userSurface;
  final double messageSpacing;
  final double draftRadius;
  final double chatBubbleRadius;
  final EdgeInsets draftPadding;
  final EdgeInsets finalPadding;
  final EdgeInsets bubblePadding;

  @override
  AppMessageStyles copyWith({
    Color? draftSurface,
    Color? finalSurface,
    Color? systemSurface,
    Color? userSurface,
    double? messageSpacing,
    double? draftRadius,
    double? chatBubbleRadius,
    EdgeInsets? draftPadding,
    EdgeInsets? finalPadding,
    EdgeInsets? bubblePadding,
  }) {
    return AppMessageStyles(
      draftSurface: draftSurface ?? this.draftSurface,
      finalSurface: finalSurface ?? this.finalSurface,
      systemSurface: systemSurface ?? this.systemSurface,
      userSurface: userSurface ?? this.userSurface,
      messageSpacing: messageSpacing ?? this.messageSpacing,
      draftRadius: draftRadius ?? this.draftRadius,
      chatBubbleRadius: chatBubbleRadius ?? this.chatBubbleRadius,
      draftPadding: draftPadding ?? this.draftPadding,
      finalPadding: finalPadding ?? this.finalPadding,
      bubblePadding: bubblePadding ?? this.bubblePadding,
    );
  }

  @override
  AppMessageStyles lerp(ThemeExtension<AppMessageStyles>? other, double t) {
    if (other is! AppMessageStyles) {
      return this;
    }

    return AppMessageStyles(
      draftSurface: Color.lerp(draftSurface, other.draftSurface, t) ?? draftSurface,
      finalSurface: Color.lerp(finalSurface, other.finalSurface, t) ?? finalSurface,
      systemSurface: Color.lerp(systemSurface, other.systemSurface, t) ?? systemSurface,
      userSurface: Color.lerp(userSurface, other.userSurface, t) ?? userSurface,
      messageSpacing: lerpDouble(messageSpacing, other.messageSpacing, t) ?? messageSpacing,
      draftRadius: lerpDouble(draftRadius, other.draftRadius, t) ?? draftRadius,
      chatBubbleRadius:
          lerpDouble(chatBubbleRadius, other.chatBubbleRadius, t) ?? chatBubbleRadius,
      draftPadding: EdgeInsets.lerp(draftPadding, other.draftPadding, t) ?? draftPadding,
      finalPadding: EdgeInsets.lerp(finalPadding, other.finalPadding, t) ?? finalPadding,
      bubblePadding: EdgeInsets.lerp(bubblePadding, other.bubblePadding, t) ?? bubblePadding,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppTextStyles get appTextStyles =>
      Theme.of(this).extension<AppTextStyles>() ??
      const AppTextStyles(
        summarySectionTitle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: AppColors.textPrimary,
        ),
        summaryContentBody: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          height: 1.55,
          color: AppColors.textPrimary,
        ),
        primaryActionButtonLabel: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: Colors.white,
        ),
      );

  AppMessageStyles get appMessageStyles =>
      Theme.of(this).extension<AppMessageStyles>() ??
      const AppMessageStyles(
        draftSurface: Color(0xFFF5F7FB),
        finalSurface: Color(0xFFF3F5F8),
        systemSurface: Color(0xFFF3F5F8),
        userSurface: Color(0xFFE6F0FF),
        messageSpacing: 8,
        draftRadius: 20,
        chatBubbleRadius: 20,
        draftPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
        finalPadding: EdgeInsets.fromLTRB(10, 10, 10, 9),
        bubblePadding: EdgeInsets.fromLTRB(10, 10, 10, 9),
      );
}

/// 统一收口应用主题，避免各页面直接散写颜色、圆角和输入框样式。
abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ).copyWith(
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.pageBackground,
    );

    // 文本层级在这里一次性定义，后续页面尽量直接复用主题语义名。
    final textTheme = base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: AppColors.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
    );

    const appTextStyles = AppTextStyles(
      summarySectionTitle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      summaryContentBody: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.55,
        color: AppColors.textPrimary,
      ),
      primaryActionButtonLabel: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: Colors.white,
      ),
    );

    const appMessageStyles = AppMessageStyles(
      draftSurface: Color(0xFFF5F7FB),
      finalSurface: Color(0xFFF3F5F8),
      systemSurface: Color(0xFFF3F5F8),
      userSurface: Color(0xFFE6F0FF),
      messageSpacing: 8,
      draftRadius: 20,
      chatBubbleRadius: 20,
      draftPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
      finalPadding: EdgeInsets.fromLTRB(10, 10, 10, 9),
      bubblePadding: EdgeInsets.fromLTRB(10, 10, 10, 9),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[appTextStyles, appMessageStyles],
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      primaryIconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerColor: AppColors.border,
      cardColor: AppColors.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, 40),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(
          color: AppColors.textHint,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
