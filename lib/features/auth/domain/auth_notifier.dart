import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';

part 'auth_notifier.g.dart';

final _log = AppLogger.getLogger('AuthNotifier');

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<void> build() {
  }

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

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      _log.i('Sign out successful');
    });
  }

  Future<bool> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).resetPassword(email);
      _log.i('[FIX] Password reset email sent');
    });
    return !state.hasError;
  }

  Future<bool> updatePassword(String newPassword) async {
    _log.d('[FIX] updatePassword called');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      _log.i('[FIX] Password updated successfully');
    });
    return !state.hasError;
  }

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

  Future<bool> resendVerification(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).resendVerificationEmail(email);
      _log.i('Verification code resent');
    });
    return !state.hasError;
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      _log.i('Google Sign-In successful');
    });
    return !state.hasError;
  }

  Future<bool> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithApple();
      _log.i('Apple Sign-In successful');
    });
    return !state.hasError;
  }
}
