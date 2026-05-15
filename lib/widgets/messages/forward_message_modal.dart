import 'package:flutter/material.dart';
import 'package:oasis/features/messages/domain/models/conversation.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class ForwardMessageModal extends StatefulWidget {
  final Message message;
  const ForwardMessageModal({super.key, required this.message});

  @override
  State<ForwardMessageModal> createState() => _ForwardMessageModalState();
}

class _ForwardMessageModalState extends State<ForwardMessageModal> {
  String _searchQuery = '';
  bool _isSending = false;
  final List<String> _selectedConversationIds = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conversations = context.watch<ConversationProvider>().conversations;

    final filteredConversations = conversations.where((c) {
      return c.otherUserName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      'Forward to...',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    if (_isSending)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search people...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredConversations.isEmpty
                    ? Center(
                        child: Text(
                          'No conversations found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredConversations.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemBuilder: (context, index) {
                          final conv = filteredConversations[index];
                          final isSelected = _selectedConversationIds.contains(
                            conv.id,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundImage: conv.otherUserAvatar.isNotEmpty
                                  ? NetworkImage(conv.otherUserAvatar)
                                  : null,
                              child: conv.otherUserAvatar.isEmpty
                                  ? Text(conv.otherUserName[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(
                              conv.otherUserName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.send_rounded,
                                color: isSelected
                                    ? Colors.green
                                    : colorScheme.primary,
                              ),
                              onPressed: _isSending || isSelected
                                  ? null
                                  : () => _forwardToConversation(conv),
                            ),
                            onTap: _isSending || isSelected
                                ? null
                                : () => _forwardToConversation(conv),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _forwardToConversation(Conversation conversation) async {
    setState(() {
      _isSending = true;
      _selectedConversationIds.add(conversation.id);
    });

    try {
      final messagingService = MessagingService();
      final authService = AuthService();
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      // When forwarding, we use the decrypted content of the source message
      // and send it as a fresh message to the target recipient.
      // The MessagingService.sendMessage handles re-encryption for the new recipient.

      await messagingService.sendMessage(
        conversationId: conversation.id,
        senderId: userId,
        content: widget.message.content == '🔒 Message encrypted'
            ? 'Forwarded message'
            : widget.message.content,
        messageType: widget.message.messageType,
        mediaUrl: widget.message.mediaUrl,
        mediaFileName: widget.message.mediaFileName,
        mediaFileSize: widget.message.mediaFileSize,
        mediaMimeType: widget.message.mediaMimeType,
        voiceDuration: widget.message.voiceDuration,
      );

      // Add optimistic update
      if (mounted) {
        context.read<ConversationProvider>().onMessageSent(
          conversation.id,
          widget.message.content == '🔒 Message encrypted'
              ? 'Forwarded message'
              : widget.message.content,
          widget.message.messageType.name,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Forwarded to ${conversation.otherUserName}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _selectedConversationIds.remove(conversation.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forward: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
