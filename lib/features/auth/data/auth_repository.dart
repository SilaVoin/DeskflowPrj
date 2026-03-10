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

/// Handles all Supabase Auth operations.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Sign in with email + password.
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

  /// Create a new account.
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

  /// Sign out current session.
  ///
  /// Uses [SignOutScope.local] by default — does NOT revoke the refresh
  /// token on the server, so it can be used later to restore the session.
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    _log.d('[FIX] signOut: scope=$scope');
    await supabaseGuard(() => _client.auth.signOut(scope: scope));
  }

  /// Restore a session using a stored refresh token.
  ///
  /// Returns the new [AuthResponse] if successful, or throws on failure.
  Future<AuthResponse> restoreSession(String refreshToken) async {
    _log.d('[FIX] restoreSession: attempting session recovery');
    return supabaseGuard(
      () => _client.auth.setSession(refreshToken),
    );
  }

  /// [FIX] Refresh the current session using the existing refresh token.
  ///
  /// Useful as a fallback when [restoreSession] fails because the token
  /// was rotated but a valid session still exists.
  Future<AuthResponse> refreshCurrentSession() async {
    _log.d('[FIX] refreshCurrentSession: attempting token refresh');
    return supabaseGuard(
      () => _client.auth.refreshSession(),
    );
  }

  /// Send password reset email.
  ///
  /// Supabase will send 6-digit OTP code (if template uses {{ .Token }}).
  Future<void> resetPassword(String email) async {
    _log.d('[FIX] resetPassword: $email');
    await supabaseGuard(
      () => _client.auth.resetPasswordForEmail(email),
    );
    _log.i('[FIX] Password reset email sent successfully');
  }

  /// Update password for the currently authenticated user.
  Future<void> updatePassword(String newPassword) async {
    _log.d('[FIX] updatePassword called');
    await supabaseGuard(
      () => _client.auth.updateUser(
        UserAttributes(password: newPassword),
      ),
    );
    _log.i('[FIX] Password updated successfully');
  }

  /// Verify recovery OTP code (from password reset email).
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

  /// Resend email verification OTP code.
  Future<void> resendVerificationEmail(String email) async {
    _log.d('resendVerificationEmail: $email');
    await supabaseGuard(() => _client.auth.resend(
          type: OtpType.signup,
          email: email,
        ));
  }

  /// Verify email with 6-digit OTP code.
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

  // ──────────────────────────── OAuth ────────────────────────────────

  /// Sign in with Google using the native SDK.
  ///
  /// Requires `GOOGLE_WEB_CLIENT_ID` (and optionally `GOOGLE_IOS_CLIENT_ID`)
  /// in env.json, and the Google provider enabled in Supabase Dashboard.
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

  /// Sign in with Apple using the native SDK.
  ///
  /// Requires the Apple provider enabled in Supabase Dashboard and
  /// Sign in with Apple capability in the iOS entitlements.
  Future<AuthResponse> signInWithApple() async {
    _log.d('signInWithApple');

    // Generate a secure random nonce
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

  /// Generate a cryptographically secure random nonce.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Get current session (null if not authenticated).
  Session? get currentSession => _client.auth.currentSession;

  /// Get current user (null if not authenticated).
  User? get currentUser => _client.auth.currentUser;

  /// Auth state change stream.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
