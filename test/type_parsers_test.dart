import 'package:flutter_test/flutter_test.dart';
import 'package:tripl/core/type_parsers.dart';

void main() {
  group('TypeParsers.parseBool', () {
    test('handles boolean types directly', () {
      expect(parseBool(true), isTrue);
      expect(parseBool(false), isFalse);
    });

    test('handles SQLite numeric representations', () {
      expect(parseBool(1), isTrue);
      expect(parseBool(0), isFalse);
      expect(parseBool(42), isTrue);
      expect(parseBool(-1), isTrue);
      expect(parseBool(0.0), isFalse);
      expect(parseBool(1.0), isTrue);
    });

    test('handles string representations case-insensitively', () {
      expect(parseBool('true'), isTrue);
      expect(parseBool('True'), isTrue);
      expect(parseBool('TRUE '), isTrue);
      expect(parseBool('1'), isTrue);

      expect(parseBool('false'), isFalse);
      expect(parseBool('False'), isFalse);
      expect(parseBool('FALSE '), isFalse);
      expect(parseBool('0'), isFalse);
    });

    test('falls back correctly for null or unknown types', () {
      expect(parseBool(null), isFalse);
      expect(parseBool(null, true), isTrue);
      expect(parseBool('random_string'), isFalse);
      expect(parseBool('random_string', true), isTrue);
      expect(parseBool([], false), isFalse);
      expect(parseBool({}, true), isTrue);
    });
  });
}
