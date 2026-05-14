import 'package:flutter/material.dart';

/// Border radius tokens.
abstract final class AppRadius {
  static const double badge   = 8;
  static const double button  = 12;
  static const double input   = 12;
  static const double card    = 18;
  static const double modal   = 24;
  static const double avatar  = 12;
  static const double chip    = 100; // pill

  static BorderRadius get cardBr   => BorderRadius.circular(card);
  static BorderRadius get buttonBr => BorderRadius.circular(button);
  static BorderRadius get inputBr  => BorderRadius.circular(input);
  static BorderRadius get badgeBr  => BorderRadius.circular(badge);
  static BorderRadius get modalBr  => BorderRadius.circular(modal);
}
