import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/config/app_config.dart';
import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';

final _log = AppLogger.getLogger('AuthRepository');

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _log.d('signInWithEmail: $email');
    return supabaseGuard(() => _client.auth.signInWithPassword(
          email: email,
          password: password,
        ));
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _log.d('signUp: $email');
    return supabaseGuard(() => _client.auth.signUp(
          email: email,
          password: password,
          data: {
            if (displayName != null) 'display_name': displayName,
          },
        ));
  }

  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    _log.d('[FIX] signOut: scope=$scope');
    await supabaseGuard(() => _client.auth.signOut(scope: scope));
  }

  Future<AuthResponse> restoreSession(String refreshToken) async {
    _log.d('[FIX] restoreSession: attempting session recovery');
    return supabaseGuard(
      () => _client.auth.setSession(refreshToken),
    );
  }

  Future<AuthResponse> refreshCurrentSession() async {
    _log.d('[FIX] refreshCurrentSession: attempting token refresh');
    return supabaseGuard(
      () => _client.auth.refreshSession(),
    );
  }

  Future<void> resetPassword(String email) async {
    _log.d('[FIX] resetPassword: $email');
    await supabaseGuard(
      () => _client.auth.resetPasswordForEmail(email),
    );
    _log.i('[FIX] Password reset email sent successfully');
  }

  Future<void> updatePassword(String newPassword) async {
    _log.d('[FIX] updatePassword called');
    await supabaseGuard(
      () => _client.auth.updateUser(
        UserAttributes(password: newPassword),
      ),
    );
    _log.i('[FIX] Password updated successfully');
  }

  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    _log.d('[FIX] verifyRecoveryOtp: $email');
    return supabaseGuard(() => _client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.recovery,
        ));
  }

  Future<void> resendVerificationEmail(String email) async {
    _log.d('resendVerificationEmail: $email');
    await supabaseGuard(() => _client.auth.resend(
          type: OtpType.signup,
          email: email,
        ));
  }

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    _log.d('verifyEmailOtp: $email');
    return supabaseGuard(() => _client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.signup,
        ));
  }


  Future<AuthResponse> signInWithGoogle() async {
    _log.d('signInWithGoogle');

    final config = AppConfig.instance;
    final webClientId = config.googleWebClientId;
    if (webClientId == null) {
      throw Exception(
        'Google Sign-In not configured. '
        'Add GOOGLE_WEB_CLIENT_ID to env.json.',
      );
    }

    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId,
      clientId: config.googleIosClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google Sign-In cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('Google Sign-In: missing ID token');
    }

    _log.d('signInWithGoogle: got tokens, calling Supabase');
    return supabaseGuard(
      () => _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      ),
    );
  }

  Future<AuthResponse> signInWithApple() async {
    _log.d('signInWithApple');

    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw Exception('Apple Sign-In: missing identity token');
    }

    _log.d('signInWithApple: got credential, calling Supabase');
    return supabaseGuard(
      () => _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      ),
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
