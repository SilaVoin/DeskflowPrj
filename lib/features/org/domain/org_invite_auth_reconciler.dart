import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deskflow/features/org/domain/org_notifier.dart';
import 'package:deskflow/features/org/domain/pending_org_invite_intent.dart';

class OrgInviteAuthReconciler {
  OrgInviteAuthReconciler(this._ref);

  final Ref _ref;
  bool _inProgress = false;

  Future<void> reconcileAfterAuth() async {
    if (_inProgress) return;
    _inProgress = true;

    try {
      final pendingIntent = _ref.read(pendingOrgInviteIntentProvider);
      final notifier = _ref.read(orgNotifierProvider.notifier);

      if (pendingIntent?.inviteToken case final token? when token.isNotEmpty) {
        await notifier.acceptInviteByToken(token);
        return;
      }

      if (pendingIntent?.inviteCode case final code? when code.isNotEmpty) {
        await notifier.acceptInviteByCode(code);
        return;
      }

      await notifier.claimPendingInvites();
    } finally {
      _inProgress = false;
    }
  }
}

final orgInviteAuthReconcilerProvider = Provider<OrgInviteAuthReconciler>(
  (ref) => OrgInviteAuthReconciler(ref),
);
