import 'package:flutter/material.dart';

/// Soft shadow tokens — no heavy dark shadows.
abstract final class AppShadows {
  /// Default card shadow.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  /// Elevated card / dropdown shadow.
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Subtle inset / pressed state.
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x07000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}
