import 'package:flutter/material.dart';

/// Shared colors and field styling for login / sign-up screens.
abstract final class SpendlyAuthTheme {
  static const borderGrey = Color(0xFFE5E5E5);
  static const mutedGrey = Color(0xFF737373);

  static InputDecoration inputDecoration({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: mutedGrey,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: borderGrey, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: borderGrey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
    );
  }
}
