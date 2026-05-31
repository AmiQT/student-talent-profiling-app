import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/showcase_models.dart';
import '../../models/user_model.dart';
import '../moderation/report_dialog.dart';
import 'media_display_widget.dart';

import '../../utils/app_theme.dart';

class PostCardWidget extends StatelessWidget {
  final ShowcasePostModel post;
  final UserModel? currentUser;
  final Function(ShowcasePostModel) onLike;
  final Function(ShowcasePostModel) onComment;
  final Function(ShowcasePostModel) onShare;
  final Function(ShowcasePostModel) onUserTap;
  final Function(ShowcasePostModel) onPostTap;
  final Function(ShowcasePostModel)? onEdit;
  final Function(ShowcasePostModel)? onDelete;

  final bool showFullContent;

  const PostCardWidget({
    super.key,
    required this.post,
    this.currentUser,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onUserTap,
    required this.onPostTap,
    this.onEdit,
    this.onDelete,
    this.showFullContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          _buildPostHeader(context),

          // Post content
          if (post.content.isNotEmpty) _buildPostContent(),

          // Media content
          if (post.hasMedia) _buildMediaContent(),

          // Category and tags
          if (post.hasTags || post.category != PostCategory.general)
            _buildCategoryAndTags(),

          // Engagement bar
          _buildEngagementBar(context),

          // Action buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildPostHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onUserTap(post),
            child: CircleAvatar(
              radius: 24,
              backgroundImage: post.userProfileImage != null &&
                      post.userProfileImage!.isNotEmpty &&
                      Uri.tryParse(post.userProfileImage!)?.hasAbsolutePath ==
                          true
                  ? CachedNetworkImageProvider(post.userProfileImage!)
                  : null,
              backgroundColor:
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: post.userProfileImage == null
                  ? Text(
                      post.userName[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => onUserTap(post),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.userName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (post.userHeadline != null &&
                      post.userHeadline!.isNotEmpty) ...[
                    Text(
                      post.userHeadline!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (post.userRole != null) ...[
                    Row(
                      children: [
                        Text(
                          post.userRole!.toUpperCase(),
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (post.userDepartment != null) ...[
                          Text(
                            ' • ${post.userDepartment}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  Text(
                    post.timeAgo,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: Theme.of(context).colorScheme.surface,
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              if (currentUser != null && post.isOwnedBy(currentUser!.uid)) ...[
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Text('Edit',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ] else ...[
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Text('Report',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                ),
              ],
              PopupMenuItem(
                value: 'copy_link',
                child: Row(
                  children: [
                    Icon(Icons.link,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface),
                    const SizedBox(width: 8),
                    Text('Copy Link',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => onPostTap(post),
        child: Builder(builder: (context) {
          return Text(
            post.content,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMediaContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: MediaDisplayWidget(
        media: post.media,
        onMediaTap: (index) => onPostTap(post),
      ),
    );
  }

  Widget _buildCategoryAndTags() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (post.category != PostCategory.general)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getCategoryColor(post.category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _getCategoryColor(post.category).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                post.categoryDisplayName,
                style: TextStyle(
                  color: _getCategoryColor(post.category),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ...post.tags.take(3).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              )),
          if (post.tags.length > 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+${post.tags.length - 3}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEngagementBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (post.likesCount > 0) ...[
            Icon(
              Icons.favorite,
              size: 16,
              color: Colors.red[400],
            ),
            const SizedBox(width: 4),
            Text(
              '${post.likesCount}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
          if (post.likesCount > 0 &&
              (post.commentsCount > 0 || post.sharesCount > 0))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          if (post.commentsCount > 0) ...[
            Text(
              '${post.commentsCount} comment${post.commentsCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
          if (post.commentsCount > 0 && post.sharesCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          if (post.sharesCount > 0) ...[
            Text(
              '${post.sharesCount} share${post.sharesCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
          const Spacer(),
          if (post.viewCount > 0)
            Text(
              '${post.viewCount} views',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // Traditional action buttons
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => onComment(post),
                  icon: Icon(
                    Icons.comment_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  label: Text(
                    'Comment',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => onShare(post),
                  icon: Icon(
                    Icons.share_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  label: Text(
                    'Share',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        if (onEdit != null) {
          onEdit!(post);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Edit feature coming soon!')),
          );
        }
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
      case 'report':
        _showReportDialog(context);
        break;
      case 'copy_link':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard!')),
        );
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onDelete != null) {
                onDelete!(post);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delete feature coming soon!')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        post: post,
        currentUser: currentUser!,
      ),
    );
  }

  Color _getCategoryColor(PostCategory category) {
    switch (category) {
      case PostCategory.academic:
        return Colors.blue;
      case PostCategory.creative:
        return Colors.purple;
      case PostCategory.technical:
        return Colors.green;
      case PostCategory.sports:
        return Colors.orange;
      case PostCategory.volunteer:
        return Colors.teal;
      case PostCategory.achievement:
        return Colors.amber;
      case PostCategory.project:
        return Colors.indigo;
      case PostCategory.general:
        return Colors.grey;
    }
  }
}
