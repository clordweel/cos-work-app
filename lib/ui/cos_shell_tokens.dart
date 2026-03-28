import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 微信壳风格配色与导航栏布局 token，随 [ThemeData] 分发（宽屏/主题迭代时可统一调整）。
@immutable
class CosShellTokens extends ThemeExtension<CosShellTokens> {
  const CosShellTokens({
    required this.pageBackground,
    required this.navBarBackground,
    required this.hairline,
    required this.titleText,
    required this.secondaryText,
    required this.capsuleBorder,
    required this.capsuleIcon,
    required this.brandGreen,
    required this.navBarTitleHorizontalPadding,
    required this.capsuleRightMargin,
  });

  /// 微信小程序风格浅色默认值。
  static const CosShellTokens light = CosShellTokens(
    pageBackground: Color(0xFFEDEDED),
    navBarBackground: Color(0xFFFFFFFF),
    hairline: Color(0xFFE5E5E5),
    titleText: Color(0xD9000000),
    secondaryText: Color(0x8C000000),
    capsuleBorder: Color(0xFFE5E5E5),
    capsuleIcon: Color(0xFF333333),
    brandGreen: Color(0xFF07C160),
    navBarTitleHorizontalPadding: 96,
    capsuleRightMargin: 7,
  );

  final Color pageBackground;
  final Color navBarBackground;
  final Color hairline;
  final Color titleText;
  final Color secondaryText;
  final Color capsuleBorder;
  final Color capsuleIcon;
  final Color brandGreen;

  /// 导航栏标题左右留白（为返回钮与胶囊让位）。
  final double navBarTitleHorizontalPadding;

  /// 胶囊相对右边缘的内边距。
  final double capsuleRightMargin;

  @override
  CosShellTokens copyWith({
    Color? pageBackground,
    Color? navBarBackground,
    Color? hairline,
    Color? titleText,
    Color? secondaryText,
    Color? capsuleBorder,
    Color? capsuleIcon,
    Color? brandGreen,
    double? navBarTitleHorizontalPadding,
    double? capsuleRightMargin,
  }) {
    return CosShellTokens(
      pageBackground: pageBackground ?? this.pageBackground,
      navBarBackground: navBarBackground ?? this.navBarBackground,
      hairline: hairline ?? this.hairline,
      titleText: titleText ?? this.titleText,
      secondaryText: secondaryText ?? this.secondaryText,
      capsuleBorder: capsuleBorder ?? this.capsuleBorder,
      capsuleIcon: capsuleIcon ?? this.capsuleIcon,
      brandGreen: brandGreen ?? this.brandGreen,
      navBarTitleHorizontalPadding:
          navBarTitleHorizontalPadding ?? this.navBarTitleHorizontalPadding,
      capsuleRightMargin: capsuleRightMargin ?? this.capsuleRightMargin,
    );
  }

  @override
  CosShellTokens lerp(ThemeExtension<CosShellTokens>? other, double t) {
    if (other is! CosShellTokens) {
      return this;
    }
    return CosShellTokens(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      navBarBackground: Color.lerp(navBarBackground, other.navBarBackground, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      titleText: Color.lerp(titleText, other.titleText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      capsuleBorder: Color.lerp(capsuleBorder, other.capsuleBorder, t)!,
      capsuleIcon: Color.lerp(capsuleIcon, other.capsuleIcon, t)!,
      brandGreen: Color.lerp(brandGreen, other.brandGreen, t)!,
      navBarTitleHorizontalPadding: lerpDouble(
        navBarTitleHorizontalPadding,
        other.navBarTitleHorizontalPadding,
        t,
      )!,
      capsuleRightMargin: lerpDouble(
        capsuleRightMargin,
        other.capsuleRightMargin,
        t,
      )!,
    );
  }
}

extension CosShellTokensContext on BuildContext {
  CosShellTokens get cosShell =>
      Theme.of(this).extension<CosShellTokens>() ?? CosShellTokens.light;
}
