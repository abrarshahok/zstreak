import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// "By continuing, you agree to our Terms and Privacy Policy." with the
/// two links actually tappable — shown under every Google sign-in/link
/// button in the app (SignInScreen, LinkAccountScreen,
/// GuestExpiredInterstitial) so the disclosure isn't just decorative text.
class TermsPrivacyNotice extends StatelessWidget {
  const TermsPrivacyNotice({
    super.key,
    required this.textMuted,
    required this.accent,
  });

  final Color textMuted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final mutedStyle = TextStyle(color: textMuted, fontSize: 11, height: 1.4);
    final linkStyle = TextStyle(
      color: accent,
      fontSize: 11,
      height: 1.4,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text('By continuing, you agree to our ', style: mutedStyle),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('https://zstreak.web.app/terms')),
          child: Text('Terms', style: linkStyle),
        ),
        Text(' and ', style: mutedStyle),
        GestureDetector(
          onTap: () =>
              launchUrl(Uri.parse('https://zstreak.web.app/privacy')),
          child: Text('Privacy Policy', style: linkStyle),
        ),
        Text('.', style: mutedStyle),
      ],
    );
  }
}
