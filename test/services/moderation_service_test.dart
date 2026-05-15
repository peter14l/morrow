import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/services/moderation_service.dart';
import 'package:oasis/models/moderation.dart';
import '../test_setup.dart';

void main() {
  setupTestEnvironment();

  group('ModerationService', () {
    group('Content Filtering', () {
      final moderationService = ModerationService();

      test('should filter blocked users from list', () {
        final items = ['user1', 'user2', 'user3', 'user4'];
        final blockedIds = {'user2', 'user4'};
        final mutedIds = <String>{};

        final filtered = moderationService.filterBlockedContent<String>(
          items,
          blockedIds,
          mutedIds,
          (item) => item,
        );

        expect(filtered, equals(['user1', 'user3']));
      });

      test('should filter muted users from list', () {
        final items = ['user1', 'user2', 'user3'];
        final blockedIds = <String>{};
        final mutedIds = {'user1'};

        final filtered = moderationService.filterBlockedContent<String>(
          items,
          blockedIds,
          mutedIds,
          (item) => item,
        );

        expect(filtered, equals(['user2', 'user3']));
      });

      test('should filter both blocked and muted users', () {
        final items = ['user1', 'user2', 'user3', 'user4'];
        final blockedIds = {'user1'};
        final mutedIds = {'user3'};

        final filtered = moderationService.filterBlockedContent<String>(
          items,
          blockedIds,
          mutedIds,
          (item) => item,
        );

        expect(filtered, equals(['user2', 'user4']));
      });

      test('should return all items when no filters', () {
        final items = ['user1', 'user2', 'user3'];
        final blockedIds = <String>{};
        final mutedIds = <String>{};

        final filtered = moderationService.filterBlockedContent<String>(
          items,
          blockedIds,
          mutedIds,
          (item) => item,
        );

        expect(filtered, equals(items));
      });

      test('should handle empty items list', () {
        final items = <String>[];
        final blockedIds = {'user1'};
        final mutedIds = {'user2'};

        final filtered = moderationService.filterBlockedContent<String>(
          items,
          blockedIds,
          mutedIds,
          (item) => item,
        );

        expect(filtered, isEmpty);
      });

      test('should work with complex objects', () {
        final posts = [
          {'id': '1', 'userId': 'user1'},
          {'id': '2', 'userId': 'user2'},
          {'id': '3', 'userId': 'user1'},
        ];
        final blockedIds = {'user1'};
        final mutedIds = <String>{};

        final filtered = moderationService
            .filterBlockedContent<Map<String, String>>(
              posts,
              blockedIds,
              mutedIds,
              (post) => post['userId']!,
            );

        expect(filtered.length, equals(1));
        expect(filtered.first['id'], equals('2'));
      });
    });
  });

  group('Report Model', () {
    test('should create Report from JSON', () {
      final json = {
        'id': 'report-123',
        'reporter_id': 'user-123',
        'reported_user_id': 'user-456',
        'post_id': null,
        'comment_id': null,
        'category': 'harassment',
        'reason': 'Inappropriate content',
        'description': 'Details of the report',
        'status': 'pending',
        'created_at': '2024-01-01T12:00:00.000Z',
      };

      final report = Report.fromJson(json);

      expect(report.id, equals('report-123'));
      expect(report.reporterId, equals('user-123'));
      expect(report.reportedUserId, equals('user-456'));
      expect(report.category, equals('harassment'));
      expect(report.status, equals('pending'));
    });

    test('should have correct status helper methods', () {
      final pendingReport = Report(
        id: 'report-1',
        reporterId: 'user-1',
        reason: 'Test',
        category: 'spam',
        createdAt: DateTime.now(),
        status: 'pending',
      );

      final resolvedReport = Report(
        id: 'report-2',
        reporterId: 'user-1',
        reason: 'Test',
        category: 'spam',
        createdAt: DateTime.now(),
        status: 'resolved',
      );

      expect(pendingReport.isPending, isTrue);
      expect(pendingReport.isResolved, isFalse);
      expect(resolvedReport.isResolved, isTrue);
      expect(resolvedReport.isPending, isFalse);
    });
  });

  group('BlockedUser Model', () {
    test('should create BlockedUser from JSON', () {
      final json = {
        'id': 'block-123',
        'blocker_id': 'user-123',
        'blocked_id': 'user-456',
        'username': 'blockeduser',
        'avatar_url': 'https://example.com/avatar.jpg',
        'reason': 'Spam',
        'created_at': '2024-01-01T12:00:00.000Z',
      };

      final blocked = BlockedUser.fromJson(json);

      expect(blocked.id, equals('block-123'));
      expect(blocked.blockedId, equals('user-456'));
      expect(blocked.username, equals('blockeduser'));
    });
  });

  group('MutedUser Model', () {
    test('should create MutedUser from JSON', () {
      final json = {
        'id': 'mute-123',
        'muter_id': 'user-123',
        'muted_id': 'user-456',
        'username': 'muteduser',
        'avatar_url': 'https://example.com/avatar.jpg',
        'reason': 'Too many posts',
        'expires_at': '2024-02-01T12:00:00.000Z',
        'created_at': '2024-01-01T12:00:00.000Z',
      };

      final muted = MutedUser.fromJson(json);

      expect(muted.id, equals('mute-123'));
      expect(muted.mutedId, equals('user-456'));
      expect(muted.username, equals('muteduser'));
      expect(muted.expiresAt, isNotNull);
    });

    test('should handle null expires_at for permanent mute', () {
      final json = {
        'id': 'mute-123',
        'muter_id': 'user-123',
        'muted_id': 'user-456',
        'username': 'muteduser',
        'avatar_url': null,
        'reason': null,
        'expires_at': null,
        'created_at': '2024-01-01T12:00:00.000Z',
      };

      final muted = MutedUser.fromJson(json);

      expect(muted.expiresAt, isNull);
      expect(muted.isPermanent, isTrue);
    });

    test('should correctly determine if mute is active or expired', () {
      final activeMute = MutedUser(
        id: 'mute-1',
        muterId: 'user-1',
        mutedId: 'user-2',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      final expiredMute = MutedUser(
        id: 'mute-2',
        muterId: 'user-1',
        mutedId: 'user-3',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(activeMute.isActive, isTrue);
      expect(activeMute.isExpired, isFalse);
      expect(expiredMute.isActive, isFalse);
      expect(expiredMute.isExpired, isTrue);
    });
  });

  group('ReportCategory', () {
    test('should have all expected categories', () {
      expect(ReportCategory.all.length, greaterThanOrEqualTo(8));
      expect(ReportCategory.all, contains('spam'));
      expect(ReportCategory.all, contains('harassment'));
      expect(ReportCategory.all, contains('hate_speech'));
    });

    test('should return display names', () {
      expect(ReportCategory.getDisplayName('spam'), equals('Spam'));
      expect(ReportCategory.getDisplayName('harassment'), equals('Harassment'));
      expect(
        ReportCategory.getDisplayName('hate_speech'),
        equals('Hate Speech'),
      );
    });
  });
}
