import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/utils/app_logger.dart';

final _log = AppLogger.getLogger('SupabaseErrorHandler');

/// Wraps a Supabase call, mapping exceptions to [DeskflowException].
Future<T> supabaseGuard<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } on AuthException catch (e) {
    _log.w('AuthException: ${e.message}');
    throw DeskflowException(
      _mapAuthError(e.message),
      code: 'AUTH_${e.statusCode}',
    );
  } on PostgrestException catch (e) {
    _log.w('PostgrestException: ${e.message} (code=${e.code})');
    throw DeskflowException(
      _mapPostgrestError(e),
      code: 'DB_${e.code}',
    );
  } on StorageException catch (e) {
    _log.w('StorageException: ${e.message}');
    throw DeskflowException(
      'Ошибка хранилища: ${e.message}',
      code: 'STORAGE_ERROR',
    );
  } on DeskflowException {
    // [FIX] Already-mapped domain exceptions — pass through as-is
    rethrow;
  } catch (e) {
    _log.e('Unexpected error: $e');
    throw DeskflowException(
      'Произошла непредвиденная ошибка',
      code: 'UNKNOWN_ERROR',
    );
  }
}

String _mapAuthError(String message) {
  return switch (message) {
    'Invalid login credentials' => 'Неверный email или пароль',
    'Email not confirmed' => 'Email не подтверждён. Проверьте почту',
    'User already registered' => 'Пользователь уже зарегистрирован',
    'Password should be at least 6 characters.' ||
    'Password should be at least 8 characters.' =>
      'Пароль должен быть минимум 8 символов',
    'Email rate limit exceeded' =>
      'Слишком много попыток. Подождите несколько минут',
    _ => 'Ошибка авторизации: $message',
  };
}

String _mapPostgrestError(PostgrestException e) {
  return switch (e.code) {
    '23505' => 'Запись уже существует',
    '23503' => 'Связанная запись не найдена',
    '42501' => 'Нет доступа к этим данным',
    'PGRST116' => 'Запись не найдена',
    _ => 'Ошибка базы данных: ${e.message}',
  };
}
