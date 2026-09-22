/// Utility functions for safely parsing heterogeneous dynamic data
/// across SQLite integers/strings and JSON booleans/numbers.
class TypeParsers {
  TypeParsers._();

  /// Parses dynamic input [val] into a [bool].
  ///
  /// Handles:
  /// - [bool]: returned directly
  /// - [num]: non-zero is true, 0 is false (SQLite boolean convention)
  /// - [String]: 'true'/'1' is true, 'false'/'0' is false (case-insensitive)
  /// - `null` or unhandled types: returns [fallback]
  static bool parseBool(dynamic val, [bool fallback = false]) {
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return fallback;
  }
}

/// Convenience top-level function that delegates to [TypeParsers.parseBool].
bool parseBool(dynamic val, [bool fallback = false]) =>
    TypeParsers.parseBool(val, fallback);
