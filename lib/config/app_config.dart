/// Compile-time configuration via `--dart-define`.
/// Example:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com --dart-define=GOOGLE_IOS_CLIENT_ID=yyy.apps.googleusercontent.com`
class AppConfig {
  AppConfig._();

  static const String _defaultGoogleWebClientId =
      '989289303049-cje9j6h9uo34ftvvknsrm5bjj6envo05.apps.googleusercontent.com';

  static const String _defaultGoogleIosClientId =
      '989289303049-gt671obarfseaiuuncvtm2ftb8sahirv.apps.googleusercontent.com';

  /// Android emulator: `http://10.0.2.2:3000`. iOS simulator: `http://127.0.0.1:3000`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  /// Web OAuth client ID (backend token audience + `serverClientId` on mobile).
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: _defaultGoogleWebClientId,
  );

  /// iOS/macOS native sign-in client ID (Google Cloud “iOS” type recommended; must match URL scheme in Info.plist).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: _defaultGoogleIosClientId,
  );
}
