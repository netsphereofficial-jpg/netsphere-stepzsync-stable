import 'package:get/get.dart';

/// In-memory cache service for non-critical data
/// ✅ SAFE: NEVER caches real-time race data, only browsing/viewing data
class CacheService extends GetxController {
  // Cache entry wrapper with expiry time
  final Map<String, _CacheEntry> _cache = {};

  /// Get cached value if it exists and hasn't expired
  /// Returns null if cache miss or expired
  T? get<T>(String key) {
    final entry = _cache[key];

    if (entry == null) {
      return null;
    }

    // Check if expired
    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(key);
      return null;
    }

    return entry.value as T;
  }

  /// Set cache value with optional TTL (Time To Live)
  /// Default TTL is 5 minutes for non-critical data
  void set<T>(
    String key,
    T value, {
    Duration ttl = const Duration(minutes: 5),
  }) {
    _cache[key] = _CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl),
    );
  }

  /// Check if a key exists in cache and is not expired
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// Remove a specific cache entry
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear all cache entries
  void clear() {
    _cache.clear();
  }

  /// Remove all expired entries (housekeeping)
  void removeExpired() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => now.isAfter(entry.expiry));
  }

  @override
  void onClose() {
    clear();
    super.onClose();
  }
}

/// Internal cache entry class
class _CacheEntry {
  final dynamic value;
  final DateTime expiry;

  _CacheEntry({
    required this.value,
    required this.expiry,
  });
}
