import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/showcase_models.dart';
import '../../models/user_model.dart';
import '../../services/showcase_service.dart';
import '../moderation/report_dialog.dart';

/// Widget for displaying a single comment
class CommentWidget extends StatefulWidget {
  final CommentModel comment;
  final UserModel? currentUser;
  final Function(CommentModel) onReply;
  final Function(CommentModel) onLike;
  final Function(CommentModel) onEdit;
  final Function(CommentModel) onDelete;
  final bool isReply;

  const CommentWidget({
    super.key,
    required this.comment,
    this.currentUser,
    required this.onReply,
    required this.onLike,
    required this.onEdit,
    required this.onDelete,
    this.isReply = false,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
          parent: _likeAnimationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = widget.currentUser != null &&
        widget.comment.isLikedBy(widget.currentUser!.uid);
    final isOwner = widget.currentUser != null &&
        widget.comment.isOwnedBy(widget.currentUser!.uid);

    return Container(
      margin: EdgeInsets.only(
        left: widget.isReply ? 40 : 0,
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: widget.isReply ? 16 : 20,
            backgroundImage: widget.comment.userProfileImage != null
                ? CachedNetworkImageProvider(widget.comment.userProfileImage!)
                : null,
            backgroundColor:
                Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: widget.comment.userProfileImage == null
                ? Text(
                    widget.comment.userName.isNotEmpty
                        ? widget.comment.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                      fontSize: widget.isReply ? 12 : 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment bubble
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white, // Always white for showcase cards
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User name and time
                      Row(
                        children: [
                          Text(
                            widget.comment.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.comment.timeAgo,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (widget.comment.isEdited) ...[
                            const SizedBox(width: 4),
                            Text(
                              '• edited',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Comment text
                      Text(
                        widget.comment.content,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Action buttons
                Row(
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: () {
                        _likeAnimationController.forward().then((_) {
                          _likeAnimationController.reverse();
                        });
                        widget.onLike(widget.comment);
                      },
                      child: AnimatedBuilder(
                        animation: _likeAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _likeAnimation.value,
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                  color:
                                      isLiked ? Colors.red : Colors.grey[600],
                                ),
                                if (widget.comment.likesCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.comment.likesCount}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Reply button
                    if (!widget.isReply)
                      GestureDetector(
                        onTap: () => widget.onReply(widget.comment),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    const Spacer(),

                    // More options
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleMenuAction(value),
                      itemBuilder: (context) => [
                        if (isOwner) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ] else ...[
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.report, size: 16),
                                SizedBox(width: 8),
                                Text('Report'),
                              ],
                            ),
                          ),
                        ],
                      ],
                      child: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        widget.onEdit(widget.comment);
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(widget.comment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    if (widget.currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        comment: widget.comment,
        currentUser: widget.currentUser!,
      ),
    );
  }
}

/// Widget for displaying comments section
class CommentSectionWidget extends StatefulWidget {
  final String postId;
  final List<CommentModel> comments;
  final UserModel? currentUser;
  final Function(String content, String? parentCommentId) onAddComment;

  const CommentSectionWidget({
    super.key,
    required this.postId,
    required this.comments,
    this.currentUser,
    required this.onAddComment,
  });

  @override
  State<CommentSectionWidget> createState() => _CommentSectionWidgetState();
}

class _CommentSectionWidgetState extends State<CommentSectionWidget> {
  final ShowcaseService _showcaseService = ShowcaseService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyingToCommentId;
  String? _replyingToUserName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topLevelComments = widget.comments
        .where((comment) => comment.parentCommentId == null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comments list
        if (topLevelComments.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...topLevelComments.map((comment) {
            final replies = widget.comments
                .where((c) => c.parentCommentId == comment.id)
                .toList();

            return Column(
              children: [
                CommentWidget(
                  comment: comment,
                  currentUser: widget.currentUser,
                  onReply: _handleReply,
                  onLike: _handleCommentLike,
                  onEdit: _handleCommentEdit,
                  onDelete: _handleCommentDelete,
                ),
                // Replies
                ...replies.map((reply) => CommentWidget(
                      comment: reply,
                      currentUser: widget.currentUser,
                      onReply: _handleReply,
                      onLike: _handleCommentLike,
                      onEdit: _handleCommentEdit,
                      onDelete: _handleCommentDelete,
                      isReply: true,
                    )),
              ],
            );
          }),
        ],

        // Comment input
        if (widget.currentUser != null) _buildCommentInput(),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply indicator
          if (_replyingToCommentId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Replying to $_replyingToUserName',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(Icons.close, size: 16, color: Colors.blue[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Comment input field
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Text(
                  widget.currentUser!.name.isNotEmpty
                      ? widget.currentUser!.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  decoration: InputDecoration(
                    hintText: _replyingToCommentId != null
                        ? 'Write a reply...'
                        : 'Write a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isSubmitting ? null : _submitComment,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleReply(CommentModel comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToUserName = comment.userName;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || widget.currentUser == null) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onAddComment(content, _replyingToCommentId);
      _commentController.clear();
      _cancelReply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleCommentLike(CommentModel comment) async {
    if (widget.currentUser == null) return;

    try {
      await _showcaseService.toggleCommentLike(
        widget.postId,
        comment.id,
        widget.currentUser!.uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like comment: $e')),
        );
      }
    }
  }

  void _handleCommentEdit(CommentModel comment) {
    _showEditCommentDialog(comment);
  }

  void _showEditCommentDialog(CommentModel comment) {
    final TextEditingController editController =
        TextEditingController(text: comment.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != comment.content) {
                try {
                  await _showcaseService.updateComment(
                    postId: widget.postId,
                    commentId: comment.id,
                    content: newContent,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Comment updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update comment: $e')),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCommentDelete(CommentModel comment) async {
    try {
      await _showcaseService.deleteComment(widget.postId, comment.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }
  }
}
