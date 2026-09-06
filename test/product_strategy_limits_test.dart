import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';

void main() {
  group('Product Strategy Logic Tests', () {
    test('User Pro status check', () {
      final freeUser = UserProfileEntity(
        id: '1',
        username: 'free',
        email: 'free@example.com',
        isPro: false,
        createdAt: DateTime.now(),
      );

      final proUser = UserProfileEntity(
        id: '2',
        username: 'pro',
        email: 'pro@example.com',
        isPro: true,
        createdAt: DateTime.now(),
      );

      expect(freeUser.isPro, isFalse);
      expect(proUser.isPro, isTrue);
    });

    test('Canvas limit calculation logic', () {
      final List<String> canvases = ['c1', 'c2'];
      const bool isPro = false;

      bool canCreateMore(List<String> list, bool pro) {
        if (!pro && list.length >= 2) return false;
        return true;
      }

      expect(canCreateMore(canvases, isPro), isFalse);
      expect(canCreateMore(canvases, true), isTrue);
      expect(canCreateMore(['c1'], isPro), isTrue);
    });
  });
}
