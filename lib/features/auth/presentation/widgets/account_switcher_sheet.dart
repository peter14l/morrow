import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:provider/provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/auth/presentation/providers/auth_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/core/extensions/context_extensions.dart';

class AccountSwitcherSheet extends StatelessWidget {
  const AccountSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    if (useFluent) {
      return _buildFluentSwitcher(context);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;
    final isSolid = ContextX(context).shouldUseSolidBackground;
    final isDark = theme.brightness == Brightness.dark;
    final authService = context.watch<AuthService>();
    final currentUserId = authService.currentUser?.id;
    final accounts = authService.registeredAccounts;
    final isLoadingRegistry = authService.isLoadingRegistry;

    debugPrint(
      '[AccountSwitcherSheet] Building with ${accounts.length} accounts. Current User: $currentUserId. Loading: $isLoadingRegistry',
    );

    final sheetContent = Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isSolid
            ? (isDark ? const Color(0xFF1A1D24) : Colors.white)
            : (disableTransparency
                  ? colorScheme.surface
                  : colorScheme.surface.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isM3E ? 48 : 28),
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Switch Account',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                letterSpacing: isM3E ? -0.5 : 0,
              ),
            ),
            const SizedBox(height: 16),

            if (isLoadingRegistry)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Accounts List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isCurrent = account.userId == currentUserId;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: EdgeInsets.all(isM3E ? 2 : 0),
                      decoration: BoxDecoration(
                        shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: isM3E ? BorderRadius.circular(12) : null,
                        border: isM3E
                            ? Border.all(color: colorScheme.primary, width: 1.5)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: isM3E
                            ? BorderRadius.circular(10)
                            : BorderRadius.circular(20),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: (account.avatarUrl ?? '').isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: account.avatarUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Text(
                                      account.username[0].toUpperCase(),
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    title: Text(
                      account.username,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? (isM3E ? FontWeight.w900 : FontWeight.bold)
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      account.email,
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCurrent)
                          Icon(Icons.check_circle, color: colorScheme.primary)
                        else
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            tooltip: 'Remove account',
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Account?'),
                                  content: Text(
                                    'Do you want to remove ${account.username} from this device?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await authService.removeAccount(
                                  context,
                                  account.userId,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    onTap: isCurrent
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await authService.switchAccount(
                              context,
                              account.userId,
                            );
                          },
                  );
                },
              ),
            ),

            const Divider(),

            // Add Account Button
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(isM3E ? 12 : 20),
                  shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                ),
                child: Icon(Icons.add, color: colorScheme.onPrimaryContainer),
              ),
              title: Text(
                'Add Account',
                style: TextStyle(
                  fontWeight: isM3E ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                authService.setAddingAccount(true);
                authService.resetProviders(context);
                context.push('/login?add_account=true');
              },
            ),
          ],
        ],
      ),
    );

    if (isSolid || disableTransparency) {
      return sheetContent;
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isM3E ? 48 : 28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: sheetContent,
      ),
    );
  }

  Widget _buildFluentSwitcher(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUserId = authService.currentUser?.id;
    final accounts = authService.registeredAccounts;
    final theme = fluent.FluentTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Switch Account', style: theme.typography.subtitle),
        ),
        const fluent.Divider(),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              final isCurrent = account.userId == currentUserId;

              return fluent.HoverButton(
                onPressed: isCurrent
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await authService.switchAccount(
                          context,
                          account.userId,
                        );
                      },
                builder: (context, states) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: fluent.ButtonThemeData.uncheckedInputColor(
                        theme,
                        states,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: (account.avatarUrl ?? '').isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: account.avatarUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: theme.accentColor.lighter,
                                    child: Center(
                                      child: Text(
                                        account.username[0].toUpperCase(),
                                        style: TextStyle(
                                          color: theme.accentColor.darker,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.username,
                                style: theme.typography.body?.copyWith(
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                              Text(
                                account.email,
                                style: theme.typography.caption,
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          Icon(
                            fluent.FluentIcons.check_mark,
                            color: theme.accentColor,
                            size: 16,
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const fluent.Divider(),
        fluent.HoverButton(
          onPressed: () {
            Navigator.pop(context);
            authService.setAddingAccount(true);
            authService.resetProviders(context);
            context.push('/login?add_account=true');
          },
          builder: (context, states) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: fluent.ButtonThemeData.uncheckedInputColor(
                  theme,
                  states,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      fluent.FluentIcons.add,
                      color: theme.accentColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Add Account', style: theme.typography.body),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (themeProvider.useFluentUI) {
      return fluent.showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) =>
            const fluent.ContentDialog(content: AccountSwitcherSheet()),
      );
    }

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AccountSwitcherSheet(),
    );
  }
}
