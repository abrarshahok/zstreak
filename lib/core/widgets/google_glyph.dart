import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Google "G" logo used on every Google sign-in/link button in the
/// app — extracted from sign_in_screen.dart's original private
/// `_GoogleGlyph` so LinkAccountScreen and GuestExpiredInterstitial's
/// buttons can show it too, instead of being plain text-only buttons that
/// don't read as "this uses Google" at a glance.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/google_logo.svg',
      width: size,
      height: size,
    );
  }
}
