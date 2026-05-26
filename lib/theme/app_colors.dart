import 'package:flutter/material.dart';

/// Central color palette for the CVAI app.
///
/// Notion-style aesthetic: light blue + white, calm and minimal.
class AppColors {
  AppColors._();

  // Primary brand
  static const primary = Color(0xFF2E5C8A); // deep professional blue
  static const primaryDark = Color(0xFF1E3A5F); // headers, important text
  static const primaryLight = Color(0xFF3A6B9A); // hover/secondary blue
  static const accent = Color(0xFF4F8FCF); // links, active states

  // Backgrounds
  static const background = Color(0xFFF7F9FC); // app background
  static const surface = Color(0xFFFFFFFF); // cards, sheets
  static const surfaceAlt = Color(0xFFF5F7FA); // alternating rows, hover

  // Text
  static const textPrimary = Color(0xFF1A1F36); // main text
  static const textSecondary = Color(0xFF6B7280); // labels, captions
  static const textMuted = Color(0xFF9CA3AF); // hints, placeholders

  // Borders & dividers
  static const border = Color(0xFFE5E7EB); // light gray border
  static const divider = Color(0xFFEEF1F5);

  // Semantic
  static const success = Color(0xFF22A05A); // present, online
  static const warning = Color(0xFFF59E0B); // late, pending
  static const danger = Color(0xFFDC2626); // absent, error, offline
  static const info = Color(0xFF3B82F6);

  // Status pill backgrounds (light tinted)
  static const successBg = Color(0xFFE8F5EE);
  static const warningBg = Color(0xFFFEF3E2);
  static const dangerBg = Color(0xFFFEE8E8);
  static const infoBg = Color(0xFFE8F1FE);

  // Soft card shadow used across the app.
  static const cardShadow = BoxShadow(
    color: Color(0x0A000000), // black @ ~4%
    blurRadius: 12,
    offset: Offset(0, 2),
  );
}
