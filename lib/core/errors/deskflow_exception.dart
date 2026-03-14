class DeskflowException implements Exception {
  final String message;
  final String? code;

  const DeskflowException(this.message, {this.code});

  static const orderAlreadyFinal = DeskflowException(
    '\u0417\u0430\u043a\u0430\u0437 \u0443\u0436\u0435 \u0432 \u0444\u0438\u043d\u0430\u043b\u044c\u043d\u043e\u043c \u0441\u0442\u0430\u0442\u0443\u0441\u0435',
    code: 'ORDER_FINAL',
  );

  static const insufficientPermissions = DeskflowException(
    '\u041d\u0435\u0434\u043e\u0441\u0442\u0430\u0442\u043e\u0447\u043d\u043e \u043f\u0440\u0430\u0432 \u0434\u043b\u044f \u044d\u0442\u043e\u0433\u043e \u0434\u0435\u0439\u0441\u0442\u0432\u0438\u044f',
    code: 'INSUFFICIENT_PERMISSIONS',
  );

  static const orgNotFound = DeskflowException(
    '\u041e\u0440\u0433\u0430\u043d\u0438\u0437\u0430\u0446\u0438\u044f \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u0430',
    code: 'ORG_NOT_FOUND',
  );

  @override
  String toString() => 'DeskflowException($code): $message';
}
