import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/domain/repositories/feed_repository.dart';
import 'package:oasis/features/feed/domain/repositories/post_repository.dart';
import 'package:oasis/features/feed/domain/repositories/comment_repository.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/features/ripples/presentation/providers/ripples_provider.dart';
import 'package:oasis/services/ad_service.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateNiceMocks([
  MockSpec<FeedRepository>(),
  MockSpec<PostRepository>(),
  MockSpec<CommentRepository>(),
  MockSpec<AdService>(),
  MockSpec<SubscriptionService>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<SupabaseQueryBuilder>(),
  MockSpec<PostgrestFilterBuilder<List<Map<String, dynamic>>>>(),
  MockSpec<PostgrestTransformBuilder<List<Map<String, dynamic>>>>(),
])
import 'ad_injection_test.mocks.dart';

void main() {
  late MockFeedRepository mockFeedRepo;
  late MockPostRepository mockPostRepo;
  late MockCommentRepository mockCommentRepo;
  late MockAdService mockAdService;
  late MockSubscriptionService mockSubService;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockFeedRepo = MockFeedRepository();
    mockPostRepo = MockPostRepository();
    mockCommentRepo = MockCommentRepository();
    mockAdService = MockAdService();
    mockSubService = MockSubscriptionService();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    // Standard auth setup
    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('user_123');

    SharedPreferences.setMockInitialValues({});
  });

  group('FeedProvider Ad Injection', () {
    test('should inject ads every 5 posts for non-pro users', () async {
      final posts = List.generate(
        10,
        (i) => Post(
          id: 'p$i',
          userId: 'u1',
          username: 'user1',
          userAvatar: '',
          timestamp: DateTime.now(),
        ),
      );

      final ads = [
        Post(
          id: 'ad1',
          userId: 'oasis',
          username: 'Oasis',
          userAvatar: '',
          timestamp: DateTime.now(),
          isAd: true,
        ),
        Post(
          id: 'ad2',
          userId: 'oasis',
          username: 'Oasis 2',
          userAvatar: '',
          timestamp: DateTime.now(),
          isAd: true,
        ),
      ];

      when(mockSubService.isPro).thenReturn(false);
      when(mockAdService.getHouseAds()).thenAnswer((_) async => ads);
      when(
        mockFeedRepo.getFeedPosts(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),
      ).thenAnswer((_) async => posts);

      final provider = FeedProvider(
        feedRepository: mockFeedRepo,
        postRepository: mockPostRepo,
        commentRepository: mockCommentRepo,
        adService: mockAdService,
        subscriptionService: mockSubService,
      );

      await provider.loadFeed(userId: 'user_123');

      expect(provider.posts.length, 12);
      expect(provider.posts[5].isAd, isTrue);
      expect(provider.posts[11].isAd, isTrue);
    });

    test('should NOT inject ads for pro users', () async {
      final posts = List.generate(
        10,
        (i) => Post(
          id: 'p$i',
          userId: 'u1',
          username: 'user1',
          userAvatar: '',
          timestamp: DateTime.now(),
        ),
      );

      when(mockSubService.isPro).thenReturn(true);
      when(
        mockFeedRepo.getFeedPosts(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),
      ).thenAnswer((_) async => posts);

      final provider = FeedProvider(
        feedRepository: mockFeedRepo,
        postRepository: mockPostRepo,
        commentRepository: mockCommentRepo,
        adService: mockAdService,
        subscriptionService: mockSubService,
      );

      await provider.loadFeed(userId: 'user_123');

      expect(provider.posts.length, 10);
      expect(provider.posts.any((p) => p.isAd), isFalse);
    });
  });

  group('RipplesProvider Ad Injection', () {
    test('should inject ads into ripples for non-pro users', () async {
      final ripples = List.generate(
        10,
        (i) => {
          'id': 'r$i',
          'user_id': 'u1',
          'video_url': 'url$i',
          'created_at': DateTime.now().toIso8601String(),
          'profiles': {'username': 'user1'},
        },
      );

      final ads = [
        Post(
          id: 'ad1',
          userId: 'oasis',
          username: 'Oasis Sponsored',
          userAvatar: '',
          timestamp: DateTime.now(),
          isAd: true,
          content: 'Ad Content',
        ),
        Post(
          id: 'ad2',
          userId: 'oasis',
          username: 'Oasis 2',
          userAvatar: '',
          timestamp: DateTime.now(),
          isAd: true,
          content: 'Ad Content 2',
        ),
      ];

      when(mockSubService.isPro).thenReturn(false);
      when(mockAdService.getHouseAds()).thenAnswer((_) async => ads);

      final mockFrom = MockSupabaseQueryBuilder();
      final mockSelect = MockPostgrestFilterBuilder();
      final mockOr = MockPostgrestFilterBuilder();
      final mockOrder = MockPostgrestTransformBuilder();

      when(mockSupabase.from('ripples')).thenAnswer((_) => mockFrom);
      when(mockFrom.select(any)).thenAnswer((_) => mockSelect);
      when(mockSelect.or(any)).thenAnswer((_) => mockOr);
      when(
        mockOr.order(any, ascending: anyNamed('ascending')),
      ).thenAnswer((_) => mockOrder);

      // Fix: when using await on a mock that implements Future, mockito needs either
      // a thenAnswer that returns a Future OR stubbing the then method correctly.
      // Since mockOrder implements Future, we can use it as the return value but
      // we must also stub the Future aspect.
      when(mockOrder.then(any, onError: anyNamed('onError'))).thenAnswer((
        invocation,
      ) {
        final callback = invocation.positionalArguments[0] as Function;
        return Future.value(ripples).then(
          (value) => callback(value),
          onError: invocation.namedArguments[const Symbol('onError')],
        );
      });

      final provider = RipplesProvider(
        supabase: mockSupabase,
        adService: mockAdService,
        subscriptionService: mockSubService,
      );

      await provider.refreshRipples();

      expect(provider.ripples.length, 12);
      expect(provider.ripples[5]['is_ad'], isTrue);
      expect(provider.ripples[11]['is_ad'], isTrue);
    });

    test('should NOT inject ads for pro users', () async {
      final ripples = List.generate(
        10,
        (i) => {
          'id': 'r$i',
          'user_id': 'u1',
          'video_url': 'url$i',
          'created_at': DateTime.now().toIso8601String(),
          'profiles': {'username': 'user1'},
        },
      );

      when(mockSubService.isPro).thenReturn(true);

      final mockFrom = MockSupabaseQueryBuilder();
      final mockSelect = MockPostgrestFilterBuilder();
      final mockOr = MockPostgrestFilterBuilder();
      final mockOrder = MockPostgrestTransformBuilder();

      when(mockSupabase.from('ripples')).thenAnswer((_) => mockFrom);
      when(mockFrom.select(any)).thenAnswer((_) => mockSelect);
      when(mockSelect.or(any)).thenAnswer((_) => mockOr);
      when(
        mockOr.order(any, ascending: anyNamed('ascending')),
      ).thenAnswer((_) => mockOrder);

      when(mockOrder.then(any, onError: anyNamed('onError'))).thenAnswer((
        invocation,
      ) {
        final callback = invocation.positionalArguments[0] as Function;
        return Future.value(ripples).then(
          (value) => callback(value),
          onError: invocation.namedArguments[const Symbol('onError')],
        );
      });

      final provider = RipplesProvider(
        supabase: mockSupabase,
        adService: mockAdService,
        subscriptionService: mockSubService,
      );

      await provider.refreshRipples();

      expect(provider.ripples.length, 10);
      expect(provider.ripples.any((r) => r['is_ad'] == true), isFalse);
    });
  });
}
