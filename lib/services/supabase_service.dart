import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/utils/logger.dart';

class SupabaseService {
  static SupabaseClient? _client;

  /// Initialize Supabase client with your project URL and anonymous key
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase client not initialized. Call initialize() first.',
      );
    }
    return _client!;
  }

  /// Get the team ID from the Teams table using the teamId (code)
  static Future<String?> getTeamIdByCode(String teamCode) async {
    try {
      final response =
          await client
              .from('Teams')
              .select('id')
              .eq('teamId', teamCode)
              .maybeSingle();

      return response?['id']?.toString();
    } catch (e) {
      AppLogger.error('Error fetching team ID', e);
      return null;
    }
  }

  /// Fetch all news articles from the Supabase 'NewsArticles' table
  static Future<List<Map<String, dynamic>>> getArticles({
    String? team,
    bool archived = false,
  }) async {
    // Start with the base query
    var query = client.from('NewsArticles').select();

    // If team code is provided (e.g., "ARI"), get its ID from Teams table and filter
    if (team != null && team.isNotEmpty) {
      final teamId = await getTeamIdByCode(team);
      if (teamId != null) {
        query = query.eq('team', teamId);
      }
    }

    if (!archived) {
      // Assuming 'current' articles are more recent (e.g., within the last month)
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      query = query.gte('created_at', cutoffDate.toIso8601String());
    }

    // Apply sorting - use .order() on the existing query
    final results = await query.order('created_at', ascending: false);

    // Return the results
    return results;
  }

  /// Subscribe to real-time changes in the NewsArticles table
  static Future<RealtimeChannel> subscribeToArticles({
    String? team,
    Function(List<Map<String, dynamic>>, String)? onInsert,
    Function(List<Map<String, dynamic>>, String)? onUpdate,
    Function(List<Map<String, dynamic>>, String)? onDelete,
  }) async {
    PostgresChangeFilter? filter;

    // If team code is provided, get its ID and create a filter
    if (team != null && team.isNotEmpty) {
      final teamId = await getTeamIdByCode(team);
      if (teamId != null) {
        filter = PostgresChangeFilter(
          column: 'team',
          type: PostgresChangeFilterType.eq,
          value: teamId,
        );
      }
    }

    final channel = client
        .channel('public:NewsArticles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'NewsArticles',
          filter: filter,
          callback: (payload) {
            // Get the event type from the payload
            final eventType = payload.eventType;

            // Convert payload data to List<Map<String, dynamic>>
            List<Map<String, dynamic>> data = [];

            switch (eventType) {
              case PostgresChangeEvent.insert:
                data = [payload.newRecord];
                onInsert?.call(data, 'insert');
                break;
              case PostgresChangeEvent.update:
                data = [payload.newRecord];
                onUpdate?.call(data, 'update');
                break;
              case PostgresChangeEvent.delete:
                data = [payload.oldRecord];
                onDelete?.call(data, 'delete');
                break;
              default:
                break;
            }
          },
        );

    return channel;
  }
}
