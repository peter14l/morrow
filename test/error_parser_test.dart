import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/utils/error_parser.dart';
import 'package:universal_io/io.dart';

void main() {
  group('ErrorParser Tests', () {
    test(
      'should map PostgrestException unique_violation to friendly message',
      () {
        const error = PostgrestException(
          message:
              'duplicate key value violates unique constraint "profiles_username_key"',
          code: '23505',
        );
        expect(ErrorParser.parse(error), 'This item already exists.');
      },
    );

    test('should map PostgrestException RLS error to permission message', () {
      const error = PostgrestException(
        message: 'new row violates row-level security policy for table "posts"',
        code: '42501',
      );
      expect(
        ErrorParser.parse(error),
        'You do not have permission to perform this action.',
      );
    });

    test('should map AuthException invalid_credentials', () {
      const error = AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      expect(ErrorParser.parse(error), 'Invalid email or password.');
    });

    test('should map SocketException to network message', () {
      const error = SocketException('Failed host lookup: "xyz.supabase.co"');
      expect(
        ErrorParser.parse(error),
        'Network connection issue. Please check your internet.',
      );
    });

    test('should return generic message for unknown errors', () {
      final error = Exception('Some internal server error 500');
      expect(
        ErrorParser.parse(error),
        'Something went wrong. Please try again.',
      );
    });

    test(
      'should return string as is if passed to CustomSnackbar (handled in widget)',
      () {
        // ErrorParser.parse handles non-string objects.
        // If a string is passed directly, we expect a generic fallback unless we specifically handle strings.
        expect(
          ErrorParser.parse('Random string'),
          'Something went wrong. Please try again.',
        );
      },
    );
  });
}
