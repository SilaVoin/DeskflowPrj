import 'package:shared_preferences/shared_preferences.dart';

import 'package:deskflow/core/utils/app_logger.dart';

final _log = AppLogger.getLogger('AccountHistoryService');

/// Service to persist recent login emails and refresh tokens in SharedPreferences.
///
/// Stores up to [maxEmails] unique email addresses, ordered by most recent.
/// Also stores refresh tokens per email so that account switching can restore
/// sessions without requiring re-authentication.
class AccountHistoryService {
  static const _key = 'deskflow_recent_emails';
  static const _tokenKeyPrefix = 'deskflow_refresh_token_';
  static const int maxEmails = 5;

  final SharedPreferences _prefs;

  AccountHistoryService(this._prefs);

  /// Returns the list of recent emails (most recent first).
  List<String> getRecentEmails() {
    final emails = _prefs.getStringList(_key) ?? [];
    _log.d('getRecentEmails: count=${emails.length}, emails=$emails');
    return emails;
  }

  /// Adds [email] to the top of the recent list.
  ///
  /// If already present, moves it to the top. Trims to [maxEmails].
  Future<void> addEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      _log.d('addEmail: skipped — empty email');
      return;
    }

    final emails = getRecentEmails();
    _log.d('addEmail: before — count=${emails.length}, adding=$normalized');

    // Remove duplicate if exists, then prepend
    emails.remove(normalized);
    emails.insert(0, normalized);

    // Trim to max
    if (emails.length > maxEmails) {
      emails.removeRange(maxEmails, emails.length);
    }

    await _prefs.setStringList(_key, emails);
    _log.i('addEmail: after — count=${emails.length}, list=$emails');
  }

  /// Removes [email] from the recent list.
  Future<void> removeEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final emails = getRecentEmails();
    _log.d('removeEmail: before — count=${emails.length}, removing=$normalized');

    emails.remove(normalized);
    await _prefs.setStringList(_key, emails);
    _log.i('removeEmail: after — count=${emails.length}');
  }

  // ──────────────── Refresh Token Storage ────────────────

  /// Saves a refresh token for [email].
  Future<void> saveRefreshToken(String email, String refreshToken) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || refreshToken.isEmpty) {
      _log.d('[FIX] saveRefreshToken: skipped — empty email or token');
      return;
    }
    final key = '$_tokenKeyPrefix$normalized';
    await _prefs.setString(key, refreshToken);
    _log.i('[FIX] saveRefreshToken: saved token for $normalized');
  }

  /// Returns the stored refresh token for [email], or null.
  String? getRefreshToken(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final key = '$_tokenKeyPrefix$normalized';
    final token = _prefs.getString(key);
    _log.d('[FIX] getRefreshToken: email=$normalized, hasToken=${token != null}');
    return token;
  }

  /// Removes the stored refresh token for [email].
  Future<void> removeRefreshToken(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final key = '$_tokenKeyPrefix$normalized';
    await _prefs.remove(key);
    _log.d('[FIX] removeRefreshToken: removed token for $normalized');
  }

  /// Clears all stored recent emails and their refresh tokens.
  Future<void> clear() async {
    _log.i('clear: removing all recent emails and tokens');
    final emails = getRecentEmails();
    for (final email in emails) {
      await removeRefreshToken(email);
    }
    await _prefs.remove(_key);
  }
}
