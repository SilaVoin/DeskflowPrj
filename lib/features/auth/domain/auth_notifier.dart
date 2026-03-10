import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';

part 'auth_notifier.g.dart';

final _log = AppLogger.getLogger('AuthNotifier');

/// Manages authentication state: login, register, sign-out, reset password.
///
/// Uses AsyncValue to expose loading / error / data states to the UI.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<void> build() {
    // No initial async work — just a state holder.
  }

  /// Sign in with email + password.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: email,
            password: password,
          );
      _log.i('Sign in successful');
    });
    return !state.hasError;
  }

  /// Register a new account.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            displayName: name,
          );
      _log.i('Registration successful');
    });
    return !state.hasError;
  }

  /// Sign out.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      _log.i('Sign out successful');
    });
  }

  /// Send password reset email.
  Future<bool> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).resetPassword(email);
      _log.i('[FIX] Password reset email sent');
    });
    return !state.hasError;
  }

  /// Update password (used after password recovery flow).
  Future<bool> updatePassword(String newPassword) async {
    _log.d('[FIX] updatePassword called');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      _log.i('[FIX] Password updated successfully');
    });
    return !state.hasError;
  }

  /// Verify recovery OTP and authenticate.
  Future<bool> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    _log.d('[FIX] verifyRecoveryOtp called');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).verifyRecoveryOtp(
            email: email,
            token: token,
          );
      _log.i('[FIX] Recovery OTP verified — user authenticated');
    });
    return !state.hasError;
  }

  /// Verify email with 6-digit OTP code.
  Future<bool> verifyEmail({
    required String email,
    required String token,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).verifyEmailOtp(
            email: email,
            token: token,
          );
      _log.i('Email verified successfully');
    });
    return !state.hasError;
  }

  /// Resend email verification OTP code.
  Future<bool> resendVerification(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).resendVerificationEmail(email);
      _log.i('Verification code resent');
    });
    return !state.hasError;
  }

  /// Sign in with Google OAuth.
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      _log.i('Google Sign-In successful');
    });
    return !state.hasError;
  }

  /// Sign in with Apple OAuth.
  Future<bool> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithApple();
      _log.i('Apple Sign-In successful');
    });
    return !state.hasError;
  }
}
