import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adapts a Supabase [Stream<AuthState>] into a [Listenable] for GoRouter.
///
/// GoRouter uses `refreshListenable` to re-evaluate redirects when auth changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  /// Manually trigger redirect re-evaluation (e.g. after org change).
  void notify() {
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
