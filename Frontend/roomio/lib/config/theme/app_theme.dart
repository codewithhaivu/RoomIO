import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:roomio/config/theme/app_text_style.dart';
/// The [AppTheme] defines light and dark themes for the app.
///
/// Theme setup for FlexColorScheme package v8.
/// Use same major flex_color_scheme package version. If you use a
/// lower minor version, some properties may not be supported.
/// In that case, remove them after copying this theme to your
/// app or upgrade the package to version 8.4.0.
///
/// Use it in a [MaterialApp] like this:
///
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
/// );
abstract final class AppTheme {
  // The FlexColorScheme defined light mode ThemeData.
  static ThemeData light = FlexThemeData.light(
    // User defined custom colors made with FlexSchemeColor() API.
    colors: const FlexSchemeColor(
      primary: Color(0xFF3B5998),
      primaryContainer: Color(0xFFA8CAE6),
      secondary: Color(0xFF55ACEE),
      secondaryContainer: Color(0xFFCBE5FF),
      tertiary: Color(0xFF4285F4),
      tertiaryContainer: Color(0xFFD6E2FF),
      appBarColor: Color(0xFFCBE5FF),
      error: Color(0xFFD31D3E),
      errorContainer: Color(0xFFFFDAD6),
    ),
    // Surface color adjustments.
    surfaceMode: FlexSurfaceMode.level,
    blendLevel: 10,
    // Convenience direct styling properties.
    transparentStatusBar: false,
    appBarElevation: 5.0,
    // Component theme configurations for light mode.
    fontFamily: 'Be Vietnam Pro',
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      textButtonRadius: 23.0,
      filledButtonRadius: 26.0,
      elevatedButtonRadius: 26.0,
      outlinedButtonRadius: 26.0,
      outlinedButtonBorderWidth: 1.0,
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorContentPadding: EdgeInsetsDirectional.fromSTEB(12, 16, 12, 12),
      inputDecoratorBackgroundAlpha: 27,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadius: 20.0,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorFocusedHasBorder: false,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.onPrimaryFixedVariant,
      inputDecoratorSuffixIconSchemeColor: SchemeColor.primary,
      cardRadius: 21.0,
      cardElevation: 8.5,
      alignedDropdown: true,
      snackBarRadius: 17,
      appBarForegroundSchemeColor: SchemeColor.primary,
      appBarActionsIconSchemeColor: SchemeColor.primary,
      appBarCenterTitle: true,
      navigationRailUseIndicator: true,
    ),
    // Direct ThemeData properties.
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
    textTheme: AppTextStyle.textTheme, // Sử dụng bộ chữ định nghĩa trong AppTextStyle
  );

  // The FlexColorScheme defined dark mode ThemeData.
  static ThemeData dark = FlexThemeData.dark(
    // User defined custom colors made with FlexSchemeColor() API.
    colors: const FlexSchemeColor(
      primary: Color(0xFF8B9DC3),
      primaryContainer: Color(0xFF3B5998),
      primaryLightRef: Color(0xFF3B5998), // The color of light mode primary
      secondary: Color(0xFFA0D1F5),
      secondaryContainer: Color(0xFF004B75),
      secondaryLightRef: Color(0xFF55ACEE), // The color of light mode secondary
      tertiary: Color(0xFF88B2F8),
      tertiaryContainer: Color(0xFF004397),
      tertiaryLightRef: Color(0xFF4285F4), // The color of light mode tertiary
      appBarColor: Color(0xFFCBE5FF),
      error: Color(0xFFCF6679),
      errorContainer: Color(0xFF93000A),
    ),
    // Convenience direct styling properties.
    transparentStatusBar: false,
    fontFamily: 'Be Vietnam Pro',
    // Component theme configurations for dark mode.
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnColors: true,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      textButtonRadius: 23.0,
      filledButtonRadius: 26.0,
      elevatedButtonRadius: 26.0,
      outlinedButtonRadius: 26.0,
      outlinedButtonBorderWidth: 1.0,
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorContentPadding: EdgeInsetsDirectional.fromSTEB(12, 16, 12, 12),
      inputDecoratorBackgroundAlpha: 40,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadius: 20.0,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorFocusedHasBorder: false,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primaryFixed,
      inputDecoratorSuffixIconSchemeColor: SchemeColor.primary,
      cardRadius: 21.0,
      cardElevation: 8.5,
      alignedDropdown: true,
      snackBarRadius: 17,
      appBarCenterTitle: true,
      navigationRailUseIndicator: true,
    ),
    // Direct ThemeData properties.
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
    textTheme: AppTextStyle.textTheme, // Sử dụng bộ chữ định nghĩa trong AppTextStyle
  );
}
