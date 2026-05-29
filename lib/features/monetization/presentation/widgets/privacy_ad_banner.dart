import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/core/config/app_config.dart';
import '../../data/services/privacy_ad_service.dart';
import '../../data/models/ad_campaign.dart';

/// Privacy-preserving contextual ad banner widget.
///
/// - Only shown if ENABLE_PRIVACY_ADS is true in AppConfig.
/// - Ads are matched locally on-device — no user data sent to server.
/// - Users can opt out via Settings (respects a local preference flag).
class PrivacyAdBanner extends StatefulWidget {
  /// The current screen category used for local ad matching.
  /// e.g. 'wellness', 'feed', 'circles', 'chat'
  final String screenCategory;

  const PrivacyAdBanner({super.key, required this.screenCategory});

  @override
  State<PrivacyAdBanner> createState() => _PrivacyAdBannerState();
}

class _PrivacyAdBannerState extends State<PrivacyAdBanner> {
  AdCampaign? _matchedAd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
  }

  void _loadAd() {
    if (!mounted) return;
    final service = context.read<PrivacyAdService>();
    final ad = service.matchAdLocally(screenCategory: widget.screenCategory);
    if (mounted) setState(() => _matchedAd = ad);
  }

  Future<void> _openAd(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gate: only show if feature flag is enabled
    if (!AppConfig.enablePrivacyAds) return const SizedBox.shrink();

    // Gate: do not show if user is a Pro member
    final isPro = context.watch<SubscriptionService>().isPro;
    if (isPro) return const SizedBox.shrink();

    // Gate: only show if we have a matched ad
    if (_matchedAd == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final ad = _matchedAd!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _openAd(ad.destinationUrl),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Ad icon/thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ad.bannerUrl.isNotEmpty
                    ? Image.network(
                        ad.bannerUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackIcon(theme),
                      )
                    : _fallbackIcon(theme),
              ),
              const SizedBox(width: 12),
              // Ad text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ad.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ad.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Privacy label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Ad · Private',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.campaign_outlined,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
