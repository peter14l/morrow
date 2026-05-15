import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/services.dart';

class ErrorParser {
  static String parse(dynamic error) {
    if (error is PostgrestException) {
      return _handlePostgrestError(error);
    } else if (error is AuthException) {
      return _handleAuthError(error);
    } else if (error is SocketException) {
      return 'Network connection issue. Please check your internet.';
    } else if (error is PlatformException) {
      return error.message ?? 'A system error occurred.';
    }

    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network') ||
        errorString.contains('xmlhttprequest')) {
      return 'Connection failed. Please try again later.';
    }

    return 'Something went wrong. Please try again.';
  }

  static String _handlePostgrestError(PostgrestException e) {
    // Map specific Postgres codes to user-friendly messages
    // without leaking table names or constraints
    switch (e.code) {
      case '23505': // unique_violation
        return 'This item already exists.';
      case '42P01': // undefined_table
      case '42703': // undefined_column
        return 'A configuration error occurred. We have been notified.';
      case 'PGRST301': // JWT expired
        return 'Your session has expired. Please log in again.';
      default:
        if (e.message.contains('row-level security')) {
          return 'You do not have permission to perform this action.';
        }
        return 'Database error. Please try again later.';
    }
  }

  static String _handleAuthError(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Invalid email or password.';
      case 'email_not_confirmed':
        return 'Please confirm your email address.';
      case 'user_not_found':
        return 'No user found with this email.';
      default:
        return e.message; // Auth messages are usually safe for users
    }
  }
}
