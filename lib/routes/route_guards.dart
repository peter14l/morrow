import 'package:go_router/go_router.dart';
import 'package:oasis/services/auth_service.dart';

/// Route guards for authentication and authorization
class RouteGuards {
  RouteGuards._();

  static final AuthService _authService = AuthService();

  /// Check if user is authenticated
  static bool isAuthenticated() {
    return _authService.currentUser != null;
  }

  /// Auth guard - returns true if should redirect to login
  static bool shouldRedirectToLogin() {
    return !isAuthenticated();
  }

  /// Guest guard - returns true if should redirect to spaces (already logged in)
  static bool shouldRedirectToSpaces() {
    return isAuthenticated();
  }

  /// Get redirect location for auth required routes
  static String getAuthRedirectLocation(String currentPath) {
    return '/login?return=$currentPath';
  }

  /// Get redirect location for guest routes (already logged in)
  static String getGuestRedirectLocation() {
    return '/';
  }
}

/// Routes that require authentication
class AuthRequiredRoutes {
  static const Set<String> authRequired = {
    '/feed',
    '/messages',
    '/notifications',
    '/profile',
    '/circles',
    '/ripples',
    '/settings',
  };

  static bool requiresAuth(String path) {
    return authRequired.any((route) => path.startsWith(route));
  }
}

/// Routes that are only for guests (not logged in)
class GuestOnlyRoutes {
  static const Set<String> guestOnly = {
    '/login',
    '/register',
    '/reset-password',
  };

  static bool isGuestOnly(String path) {
    return guestOnly.contains(path);
  }
}

/// Get return URL from login redirect
String? getReturnUrlFromState(GoRouterState state) {
  final queryParams = state.uri.queryParameters;
  if (queryParams.containsKey('return')) {
    return queryParams['return'];
  }
  return null;
}
