import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingOrgInviteIntent {
  final String? inviteToken;
  final String? inviteCode;

  const PendingOrgInviteIntent._({
    this.inviteToken,
    this.inviteCode,
  });

  const PendingOrgInviteIntent.token(String inviteToken)
      : this._(inviteToken: inviteToken);

  const PendingOrgInviteIntent.code(String inviteCode)
      : this._(inviteCode: inviteCode);
}

class PendingOrgInviteIntentNotifier
    extends StateNotifier<PendingOrgInviteIntent?> {
  PendingOrgInviteIntentNotifier() : super(null);

  void setToken(String inviteToken) {
    state = PendingOrgInviteIntent.token(inviteToken);
  }

  void setCode(String inviteCode) {
    state = PendingOrgInviteIntent.code(inviteCode);
  }

  void clear() {
    state = null;
  }
}

final pendingOrgInviteIntentProvider = StateNotifierProvider<
    PendingOrgInviteIntentNotifier, PendingOrgInviteIntent?>(
  (ref) => PendingOrgInviteIntentNotifier(),
);
