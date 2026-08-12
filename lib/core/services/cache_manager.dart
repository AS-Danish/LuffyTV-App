import 'package:supabase_flutter/supabase_flutter.dart';

class CacheManager {
  static const String tableName = 'api_cache';
  
  // Time-To-Live in hours
  static const int ttlHours = 1;

  final SupabaseClient supabase;

  CacheManager({required this.supabase});

  Future<Map<String, dynamic>?> get(String key) async {
    try {
      final response = await supabase
          .from(tableName)
          .select()
          .eq('id', key)
          .maybeSingle();

      if (response == null) {
        return null; // Cache miss
      }

      final updatedAtStr = response['updated_at'] as String;
      final updatedAt = DateTime.parse(updatedAtStr);
      final now = DateTime.now().toUtc();

      if (now.difference(updatedAt).inHours >= ttlHours) {
        // Cache expired
        return null;
      }

      // Return cached JSON data
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      // On any Supabase error (e.g. offline, table not created), just return null to fallback to API
      print('CacheManager get error: $e');
      return null;
    }
  }

  Future<void> set(String key, Map<String, dynamic> data) async {
    try {
      await supabase.from(tableName).upsert({
        'id': key,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print('CacheManager set error: $e');
    }
  }
}
