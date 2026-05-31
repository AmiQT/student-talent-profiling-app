import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/showcase_models.dart';
import '../../models/user_model.dart';
import '../../services/showcase_service.dart';

/// Widget for sharing posts
class ShareWidget extends StatelessWidget {
  final ShowcasePostModel post;
  final UserModel? currentUser;

  const ShareWidget({
    super.key,
    required this.post,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Share Post',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Share options
          _buildShareOption(
            context,
            icon: Icons.link,
            title: 'Copy Link',
            subtitle: 'Copy post link to clipboard',
            onTap: () => _copyLink(context),
          ),

          _buildShareOption(
            context,
            icon: Icons.people,
            title: 'Share with Friends',
            subtitle: 'Share within the app',
            onTap: () => _shareWithFriends(context),
          ),

          _buildShareOption(
            context,
            icon: Icons.share,
            title: 'Share Externally',
            subtitle: 'Share to other apps',
            onTap: () => _shareExternally(context),
          ),

          const SizedBox(height: 20),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, // Always white for showcase cards
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red[50]
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? Colors.red
                      : Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    try {
      // Generate post link (this would be a deep link in a real app)
      final postLink = 'https://talentshowcase.app/post/${post.id}';

      await Clipboard.setData(ClipboardData(text: postLink));

      // Track share
      if (currentUser != null) {
        final showcaseService = ShowcaseService();
        await showcaseService.sharePost(post.id, currentUser!.uid);
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy link: $e')),
        );
      }
    }
  }

  void _shareWithFriends(BuildContext context) {
    Navigator.pop(context);

    // Show user selection dialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FriendsShareWidget(
        post: post,
        currentUser: currentUser,
      ),
    );
  }

  Future<void> _shareExternally(BuildContext context) async {
    Navigator.pop(context);

    try {
      // Generate post link and content for sharing
      final postLink = 'https://talentshowcase.app/post/${post.id}';
      final shareText = '''
Check out this amazing post by ${post.userName}!

"${post.content.length > 100 ? '${post.content.substring(0, 100)}...' : post.content}"

View the full post: $postLink

#TalentShowcase #${post.category.toString().split('.').last}
''';

      // Track share before sharing
      if (currentUser != null) {
        final showcaseService = ShowcaseService();
        await showcaseService.sharePost(post.id, currentUser!.uid);
      }

      // Share using the share_plus package
      await Share.share(
        shareText,
        subject: 'Check out this post from Talent Showcase',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }
}

/// Widget for sharing with friends within the app
class FriendsShareWidget extends StatefulWidget {
  final ShowcasePostModel post;
  final UserModel? currentUser;

  const FriendsShareWidget({
    super.key,
    required this.post,
    this.currentUser,
  });

  @override
  State<FriendsShareWidget> createState() => _FriendsShareWidgetState();
}

class _FriendsShareWidgetState extends State<FriendsShareWidget> {
  final TextEditingController _searchController = TextEditingController();
  final List<UserModel> _selectedUsers = [];
  List<UserModel> _friends = []; // This would be loaded from a friends service
  List<UserModel> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFriends() async {
    // Load friends from a friends service
    try {
      if (widget.currentUser != null) {
        // In a real implementation, you would have a FriendsService
        // For now, we'll simulate loading friends by getting sample users
        // This is a simplified implementation - in reality you'd have a proper friends system

        // Create some sample friends for demonstration
        _friends = [
          UserModel(
            id: 'friend1',
            uid: 'friend1_uid',
            email: 'friend1@example.com',
            name: 'Alice Johnson',
            role: UserRole.student,
            department: 'Computer Science',
            createdAt: DateTime.now(),
          ),
          UserModel(
            id: 'friend2',
            uid: 'friend2_uid',
            email: 'friend2@example.com',
            name: 'Bob Smith',
            role: UserRole.student,
            department: 'Information Technology',
            createdAt: DateTime.now(),
          ),
          UserModel(
            id: 'friend3',
            uid: 'friend3_uid',
            email: 'friend3@example.com',
            name: 'Dr. Carol Wilson',
            role: UserRole.lecturer,
            department: 'Computer Science',
            createdAt: DateTime.now(),
          ),
        ];

        if (mounted) {
          setState(() {
            _filteredFriends = _friends;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      // Keep empty list on error
      _filteredFriends = [];
    }
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFriends = _friends.where((friend) {
        return friend.name.toLowerCase().contains(query) ||
            friend.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Share with Friends',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search friends...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Selected users
          if (_selectedUsers.isNotEmpty) ...[
            const Text(
              'Selected:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = _selectedUsers[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(user.name),
                      onDeleted: () {
                        setState(() {
                          _selectedUsers.remove(user);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Friends list
          Expanded(
            child: _friends.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No friends yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Connect with other users to share posts',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = _filteredFriends[index];
                      final isSelected = _selectedUsers.contains(friend);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
                          child: Text(
                            friend.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(friend.name),
                        subtitle: Text(friend.email),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedUsers.remove(friend);
                            } else {
                              _selectedUsers.add(friend);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),

          // Share button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedUsers.isNotEmpty ? _shareWithSelected : null,
              child: Text(
                  'Share with ${_selectedUsers.length} friend${_selectedUsers.length == 1 ? '' : 's'}'),
            ),
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _shareWithSelected() async {
    try {
      // Implement actual sharing logic
      // This sends notifications to selected users and tracks the share

      if (widget.currentUser != null && _selectedUsers.isNotEmpty) {
        final showcaseService = ShowcaseService();

        // Track the share in the post
        await showcaseService.sharePost(
            widget.post.id, widget.currentUser!.uid);

        // In a real implementation, you would:
        // 1. Send notifications to selected users
        // 2. Create activity feed entries
        // 3. Update user's sharing history

        // For now, we'll simulate this with a simple notification system
        for (final user in _selectedUsers) {
          debugPrint(
              'Sharing post ${widget.post.id} with user ${user.name} (${user.uid})');

          // Here you would typically:
          // - Create a notification record in the database
          // - Send push notification if the user has notifications enabled
          // - Add to their activity feed

          // Example notification data:
          // {
          //   'type': 'post_shared',
          //   'fromUserId': widget.currentUser!.uid,
          //   'fromUserName': widget.currentUser!.name,
          //   'toUserId': user.uid,
          //   'postId': widget.post.id,
          //   'postContent': widget.post.content.substring(0, 100),
          //   'createdAt': DateTime.now().toIso8601String(),
          // }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Post shared with ${_selectedUsers.length} friend${_selectedUsers.length == 1 ? '' : 's'}!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share post: $e')),
        );
      }
    }
  }
}
