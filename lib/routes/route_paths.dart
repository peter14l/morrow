/// Route path constants for the application
class RoutePaths {
  RoutePaths._();

  // Auth routes
  static const String login = '/login';
  static const String register = '/register';
  static const String resetPassword = '/reset-password';
  static const String onboarding = '/onboarding';

  // Main routes
  static const String spaces = '/';
  static const String feed = '/feed';
  static const String search = '/search';
  static const String messages = '/messages';
  static const String notifications = '/notifications';
  static const String settings = '/settings';

  // Feature routes
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String followers = '/profile/followers';
  static const String circles = '/circles';
  static const String createCircle = '/circles/create';
  static const String circleDetail = '/circles/:id';
  static const String circleJoin = '/circles/join';
  static const String createCommitment = '/circles/:id/commitment/create';
  static const String ripples = '/ripples';
  static const String stories = '/stories';
  static const String createStory = '/stories/create';
  static const String storyView = '/stories/:id';
  static const String communities = '/communities';
  static const String communityDetail = '/communities/:id';
  static const String collections = '/collections';
  static const String collectionDetail = '/collections/:id';
  static const String chat = '/chat/:id';
  static const String newMessage = '/messages/new';
  static const String postDetails = '/post/:id';
  static const String comments = '/post/:id/comments';
  static const String createPost = '/post/create';
  static const String hashtag = '/hashtag/:tag';
  static const String activeCall = '/call/:id';
  static const String encryptionSetup = '/messages/encryption-setup';
  static const String chatDetails = '/chat/:id/details';

  // Settings sub-routes
  static const String accountPrivacy = '/settings/privacy';
  static const String twoFactorAuth = '/settings/2fa';
  static const String downloadData = '/settings/download';
  static const String storageUsage = '/settings/storage';
  static const String fontSize = '/settings/font-size';
  static const String helpSupport = '/settings/help';
  static const String subscription = '/settings/subscription';
  static const String digitalWellbeing = '/settings/wellbeing';
  static const String screenTime = '/settings/screen-time';
  static const String wellnessStats = '/settings/wellness-stats';
  static const String vaultSettings = '/settings/vault';
  static const String deleteAccount = '/settings/delete-account';
  static const String about = '/settings/about';

  // Legal routes
  static const String privacyPolicy = '/settings/about/privacy-policy';
  static const String termsOfService = '/settings/about/terms-of-service';
  static const String changelog = '/settings/about/changelog';

  // Pro routes
  static const String oasisPro = '/pro';

  // Moderation
  static const String moderation = '/moderation';
}
