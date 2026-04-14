import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/app_config.dart';

/// Google and Sign in with Apple. Configure OAuth in Google Cloud / Apple Developer.
class SocialAuthService {
  SocialAuthService._();

  static GoogleSignIn? _googleSignIn;

  static String? get _iosMacGoogleClientId {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        final id = AppConfig.googleIosClientId;
        return id.isEmpty ? null : id;
      default:
        return null;
    }
  }

  static GoogleSignIn get _google {
    _googleSignIn ??= GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      clientId: _iosMacGoogleClientId,
      serverClientId: AppConfig.googleWebClientId.isEmpty
          ? null
          : AppConfig.googleWebClientId,
    );
    return _googleSignIn!;
  }

  /// Returns a Google [idToken] for the backend ([AppConfig.googleWebClientId] / `serverClientId`).
  static Future<SocialGoogleSignInResult?> signInWithGoogleForBackend() async {
    final account = await _google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google did not return an ID token. Pass your Web OAuth client ID as '
        'GOOGLE_WEB_CLIENT_ID via --dart-define.',
      );
    }
    return SocialGoogleSignInResult(
      email: account.email,
      displayName: account.displayName,
      idToken: idToken,
    );
  }

  static Future<void> signOutGoogle() async {
    await _google.signOut();
  }

  static Future<AuthorizationCredentialAppleID> signInWithApple() async {
    return SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
  }

  static String describeError(Object e, StackTrace st) {
    if (e is PlatformException) {
      return e.message ?? e.code;
    }
    if (kDebugMode) {
      debugPrint('SocialAuthService error: $e\n$st');
    }
    return e.toString();
  }
}

class SocialGoogleSignInResult {
  SocialGoogleSignInResult({
    required this.email,
    required this.displayName,
    required this.idToken,
  });

  final String email;
  final String? displayName;
  final String idToken;
}
