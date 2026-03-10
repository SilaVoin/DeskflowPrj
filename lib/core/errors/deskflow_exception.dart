/// Base exception for all Deskflow domain errors.
///
/// Provides user-friendly Russian messages and machine-readable codes.
class DeskflowException implements Exception {
  final String message;
  final String? code;

  const DeskflowException(this.message, {this.code});

  // ── Auth ──────────────────────────────────────────────
  static const invalidCredentials = DeskflowException(
    'Неверный email или пароль',
    code: 'INVALID_CREDENTIALS',
  );

  static const emailNotConfirmed = DeskflowException(
    'Email не подтверждён',
    code: 'EMAIL_NOT_CONFIRMED',
  );

  static const userAlreadyRegistered = DeskflowException(
    'Пользователь уже зарегистрирован',
    code: 'USER_ALREADY_REGISTERED',
  );

  static const weakPassword = DeskflowException(
    'Пароль слишком простой (минимум 8 символов)',
    code: 'WEAK_PASSWORD',
  );

  // ── Org ───────────────────────────────────────────────
  static const orgNotFound = DeskflowException(
    'Организация не найдена',
    code: 'ORG_NOT_FOUND',
  );

  static const invalidInviteCode = DeskflowException(
    'Неверный код приглашения',
    code: 'INVALID_INVITE_CODE',
  );

  static const alreadyMember = DeskflowException(
    'Вы уже являетесь участником этой организации',
    code: 'ALREADY_MEMBER',
  );

  // ── Orders ────────────────────────────────────────────
  static const orderAlreadyFinal = DeskflowException(
    'Заказ уже в финальном статусе',
    code: 'ORDER_FINAL',
  );

  // ── Access ────────────────────────────────────────────
  static const insufficientPermissions = DeskflowException(
    'Недостаточно прав для этого действия',
    code: 'INSUFFICIENT_PERMISSIONS',
  );

  // ── Network ───────────────────────────────────────────
  static const noConnection = DeskflowException(
    'Нет подключения к интернету',
    code: 'NO_CONNECTION',
  );

  static const serverError = DeskflowException(
    'Ошибка сервера. Попробуйте позже',
    code: 'SERVER_ERROR',
  );

  @override
  String toString() => 'DeskflowException($code): $message';
}
