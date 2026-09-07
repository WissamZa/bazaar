import 'package:flutter/material.dart';

/// Layout and shape tokens shared by every screen. Keeping spacing, radii
/// and borders here is what makes the redesign feel coherent — widgets
/// reference these constants instead of inventing their own paddings.
abstract final class AppDimens {
  // Spacing scale (4 pt grid).
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  // Radii.
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXl = 24;

  // Component sizes.
  static const double minTouchTarget = 48;
  static const double listItemImage = 52;
  static const double storeAvatar = 44;
  static const double kpiIconBox = 40;
  static const double scanReticle = 240;

  // Screen edge padding for page content.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: space4,
    vertical: space3,
  );
}
