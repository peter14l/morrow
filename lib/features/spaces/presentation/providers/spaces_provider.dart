import 'package:flutter/foundation.dart';
import '../../domain/models/navigation_entity.dart';

/// Immutable state for navigation/spaces
class SpacesState {
  final AppShellEntity appShell;
  final bool isLoading;
  final String? error;
  final bool isOnline;

  const SpacesState({
    required this.appShell,
    this.isLoading = false,
    this.error,
    this.isOnline = true,
  });

  factory SpacesState.initial() {
    return SpacesState(appShell: AppShellEntity.initial());
  }

  SpacesState copyWith({
    AppShellEntity? appShell,
    bool? isLoading,
    String? error,
    bool? isOnline,
  }) {
    return SpacesState(
      appShell: appShell ?? this.appShell,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  NavigationTabEntity? get currentTab => appShell.currentTab;
  List<NavigationTabEntity> get tabs => appShell.tabs;
}

/// Provider for navigation state
class SpacesProvider extends ChangeNotifier {
  SpacesState _state = SpacesState.initial();

  SpacesState get state => _state;
  AppShellEntity get appShell => _state.appShell;
  NavigationTabEntity? get currentTab => _state.currentTab;
  List<NavigationTabEntity> get tabs => _state.tabs;
  bool get isOnline => _state.isOnline;

  /// Navigate to a tab by ID
  void navigateToTab(String tabId) {
    final tab = _state.appShell.tabs.firstWhere(
      (t) => t.id == tabId,
      orElse: () => _state.appShell.tabs.first,
    );

    final updatedTabs = _state.appShell.tabs
        .map((t) => t.copyWith(isSelected: t.id == tabId))
        .toList();

    _state = _state.copyWith(
      appShell: _state.appShell.copyWith(
        currentRoute: tab.route,
        tabs: updatedTabs,
      ),
    );
    notifyListeners();
  }

  /// Navigate to a tab by route
  void navigateToRoute(String route) {
    final updatedTabs = _state.appShell.tabs
        .map((t) => t.copyWith(isSelected: t.route == route))
        .toList();

    _state = _state.copyWith(
      appShell: _state.appShell.copyWith(
        currentRoute: route,
        tabs: updatedTabs,
      ),
    );
    notifyListeners();
  }

  /// Update badge count for a tab
  void updateBadgeCount(String tabId, int count) {
    final updatedTabs = _state.appShell.tabs.map((tab) {
      if (tab.id == tabId) {
        return tab.copyWith(badgeCount: count);
      }
      return tab;
    }).toList();

    _state = _state.copyWith(
      appShell: _state.appShell.copyWith(tabs: updatedTabs),
    );
    notifyListeners();
  }

  /// Increment badge for a tab
  void incrementBadge(String tabId) {
    final tab = _state.appShell.tabs.firstWhere((t) => t.id == tabId);
    updateBadgeCount(tabId, (tab.badgeCount ?? 0) + 1);
  }

  /// Clear badge for a tab
  void clearBadge(String tabId) {
    updateBadgeCount(tabId, 0);
  }

  /// Update online status
  void setOnlineStatus(bool isOnline) {
    _state = _state.copyWith(isOnline: isOnline);
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }
}
