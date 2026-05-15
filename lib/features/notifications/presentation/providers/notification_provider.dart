import 'package:flutter/foundation.dart';
import 'package:oasis/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:oasis/features/notifications/domain/models/notification_entity.dart';
import 'package:oasis/features/notifications/domain/repositories/notification_repository.dart';
import 'package:oasis/features/notifications/domain/usecases/notification_usecases.dart';
import 'package:oasis/features/notifications/presentation/providers/notification_state.dart';

class NotificationProvider extends ChangeNotifier {
  final GetNotifications _getNotifications;
  final MarkNotificationRead _markNotificationRead;
  final MarkAllNotificationsRead _markAllNotificationsRead;
  final DeleteAllNotifications _deleteAllNotifications;
  final GetUnreadNotificationCount _getUnreadCount;

  NotificationState _state = const NotificationState();
  NotificationState get state => _state;

  NotificationProvider({NotificationRepository? repository})
    : _getNotifications = GetNotifications(
        repository ?? NotificationRepositoryImpl(),
      ),
      _markNotificationRead = MarkNotificationRead(
        repository ?? NotificationRepositoryImpl(),
      ),
      _markAllNotificationsRead = MarkAllNotificationsRead(
        repository ?? NotificationRepositoryImpl(),
      ),
      _deleteAllNotifications = DeleteAllNotifications(
        repository ?? NotificationRepositoryImpl(),
      ),
      _getUnreadCount = GetUnreadNotificationCount(
        repository ?? NotificationRepositoryImpl(),
      );

  Future<void> loadNotifications({bool refresh = false}) async {
    if (refresh) {
      _state = _state.copyWith(
        loadingState: NotificationLoadingState.loading,
        currentOffset: 0,
        notifications:
            [], // Clear on refresh to avoid showing stale data during reload
      );
    } else {
      _state = _state.copyWith(loadingState: NotificationLoadingState.loading);
    }
    notifyListeners();

    final result = await _getNotifications(
      limit: 50,
      offset: refresh ? 0 : _state.currentOffset,
    );

    result.fold(
      onFailure: (failure) {
        _state = _state.copyWith(
          loadingState: NotificationLoadingState.error,
          errorMessage: failure.message,
        );
      },
      onSuccess: (newNotifications) {
        List<AppNotification> updatedList;
        if (refresh) {
          updatedList = newNotifications;
        } else {
          // Deduplicate based on notification ID to prevent duplicates
          final existingIds = _state.notifications.map((n) => n.id).toSet();
          final uniqueNew = newNotifications
              .where((n) => !existingIds.contains(n.id))
              .toList();
          updatedList = [..._state.notifications, ...uniqueNew];
        }

        _state = _state.copyWith(
          loadingState: NotificationLoadingState.loaded,
          notifications: updatedList,
          hasMore: newNotifications.length >= 50,
          currentOffset: refresh
              ? newNotifications.length
              : _state.currentOffset + newNotifications.length,
          errorMessage: null,
        );
      },
    );
    notifyListeners();

    // Also fetch unread count
    await refreshUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    final result = await _getUnreadCount();
    result.fold(
      onFailure: (_) {},
      onSuccess: (count) {
        _state = _state.copyWith(unreadCount: count);
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final result = await _markNotificationRead(notificationId);
    result.fold(
      onFailure: (_) {},
      onSuccess: (_) {
        final updatedNotifications = _state.notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList();

        _state = _state.copyWith(
          notifications: updatedNotifications,
          unreadCount: _state.unreadCount > 0 ? _state.unreadCount - 1 : 0,
        );
        notifyListeners();
      },
    );
  }

  Future<void> markAllAsRead() async {
    final result = await _markAllNotificationsRead();
    result.fold(
      onFailure: (_) {},
      onSuccess: (_) {
        final updatedNotifications = _state.notifications.map((n) {
          return n.copyWith(isRead: true);
        }).toList();

        _state = _state.copyWith(
          notifications: updatedNotifications,
          unreadCount: 0,
        );
        notifyListeners();
      },
    );
  }

  Future<void> deleteAllNotifications() async {
    final result = await _deleteAllNotifications();
    result.fold(
      onFailure: (_) {},
      onSuccess: (_) {
        _state = _state.copyWith(
          notifications: [],
          unreadCount: 0,
          currentOffset: 0,
          hasMore: false,
        );
        notifyListeners();
      },
    );
  }

  Future<void> loadMore() async {
    if (_state.hasMore &&
        _state.loadingState != NotificationLoadingState.loading) {
      await loadNotifications();
    }
  }

  int get unreadCount => _state.unreadCount;
  List<AppNotification> get notifications => _state.notifications;

  void init(String? userId) {
    if (userId == null) {
      clear();
    } else {
      loadNotifications(refresh: true);
    }
  }

  void clear() {
    _state = const NotificationState();
    notifyListeners();
  }
}
