import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/errors/supabase_error_handler.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/search/domain/search_history_entry.dart';

final _log = AppLogger.getLogger('SearchHistoryRepository');

class SearchHistoryRepository {
  SearchHistoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<SearchHistoryEntry>> listRecent({
    required String userId,
    int limit = 20,
  }) async {
    _log.d('listRecent: userId=$userId, limit=$limit');
    return supabaseGuard(() async {
      final data = await _client
          .from('search_history')
          .select()
          .eq('user_id', userId)
          .order('last_used_at', ascending: false)
          .limit(limit);

      return (data as List)
          .map((entry) => SearchHistoryEntry.fromJson(entry))
          .toList();
    });
  }

  Future<void> saveExecutedQuery({
    required String userId,
    required String query,
  }) async {
    final normalizedQuery = normalizeSearchHistoryQuery(query);
    if (normalizedQuery.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    _log.d('saveExecutedQuery: userId=$userId, query="$normalizedQuery"');
    await supabaseGuard(() async {
      await _client.from('search_history').upsert({
        'user_id': userId,
        'query_text': normalizedQuery,
        'normalized_query': searchHistoryQueryKey(normalizedQuery),
        'last_used_at': now,
      }, onConflict: 'user_id,normalized_query');
    });
  }
}
