/// Google Sign-In configuration.
///
/// google_sign_in v7's Credential Manager-based Android implementation no
/// longer auto-derives its client ID from google-services.json the way
/// older versions did — it throws `GoogleSignInExceptionCode
/// .clientConfigurationError` ("serverClientId must be provided on
/// Android") unless this is supplied explicitly to `initialize()`.
class GoogleSignInConfig {
  GoogleSignInConfig._();

  /// The **Web application** OAuth client ID from the Firebase/Google
  /// Cloud console — NOT one of the Android client IDs. In
  /// android/app/google-services.json this is the `oauth_client` entry
  /// with `"client_type": 3` (there's exactly one; the `client_type: 1`
  /// entries are per-signing-certificate Android client IDs and won't
  /// work here).
  static const String androidServerClientId =
      '245868538464-dtg5g98eva4i246n04j31345ivphnph4.apps.googleusercontent.com';
}
