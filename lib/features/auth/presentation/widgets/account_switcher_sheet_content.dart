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
