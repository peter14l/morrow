import 'dart:async';
import '../../domain/models/navigation_entity.dart';
import '../../domain/repositories/spaces_repository.dart';

/// Implementation of SpacesRepository
class SpacesRepositoryImpl implements SpacesRepository {
  AppShellEntity _appShell = AppShellEntity.initial();
  final _tabController = StreamController<NavigationTabEntity>.broadcast();
  bool _isOnline = true;

  @override
  AppShellEntity getAppShell() {
    return _appShell.copyWith(isOnline: _isOnline);
  }

  @override
  Future<void> updateBadgeCount(String tabId, int count) async {
    final tabs = _appShell.tabs.map((tab) {
      if (tab.id == tabId) {
        return tab.copyWith(badgeCount: count);
      }
      return tab;
    }).toList();
    _appShell = _appShell.copyWith(tabs: tabs);
  }

  @override
  Future<void> navigateToTab(String tabId) async {
    final tab = _appShell.tabs.firstWhere(
      (t) => t.id == tabId,
      orElse: () => _appShell.tabs.first,
    );
    _appShell = _appShell.copyWith(
      currentRoute: tab.route,
      tabs: _appShell.tabs
          .map((t) => t.copyWith(isSelected: t.id == tabId))
          .toList(),
    );
    _tabController.add(tab);
  }

  @override
  NavigationTabEntity? getCurrentTab() {
    return _appShell.currentTab;
  }

  @override
  Stream<NavigationTabEntity> watchCurrentTab() {
    return _tabController.stream;
  }

  @override
  Future<void> updateOnlineStatus(bool isOnline) async {
    _isOnline = isOnline;
  }

  void dispose() {
    _tabController.close();
  }
}
