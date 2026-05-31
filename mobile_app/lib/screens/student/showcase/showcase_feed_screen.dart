import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/showcase_models.dart';
import '../../../models/user_model.dart';
import '../../../services/showcase_service.dart';
import '../../../services/supabase_auth_service.dart';

import '../../../widgets/common/skeleton_widgets.dart';
import '../../../widgets/common/refresh_indicator.dart' as custom_refresh;

import '../../../utils/app_theme.dart';
import '../../../widgets/modern/glass_showcase_card.dart';

// Using native Flutter widgets for competition simplicity
import 'post_creation_screen.dart';
import 'post_detail_screen.dart';

class ShowcaseFeedScreen extends StatefulWidget {
  final PostCategory? filterCategory;
  final String? filterUserId;

  const ShowcaseFeedScreen({
    super.key,
    this.filterCategory,
    this.filterUserId,
  });

  @override
  State<ShowcaseFeedScreen> createState() => _ShowcaseFeedScreenState();
}

class _ShowcaseFeedScreenState extends State<ShowcaseFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final ShowcaseService _showcaseService = ShowcaseService();
  final ScrollController _scrollController = ScrollController();

  // Debug flag to disable real-time updates
  static const bool _enableRealTimeUpdates =
      true; // Enable real-time updates for better UX

  // State variables
  List<ShowcasePostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  PostCategory? _selectedCategory;
  UserModel? _currentUser;

  // Pagination - OPTIMIZED for faster initial load
  static const int _postsPerPage =
      6; // Reduced from 10 for faster homepage loading

  // Stream subscription with lifecycle management
  StreamSubscription<List<ShowcasePostModel>>? _postsSubscription;
  bool _isSubscriptionActive = false; // Prevent multiple subscriptions

  /// Batch state updates to reduce setState calls and improve performance
  void _updateFeedState({
    List<ShowcasePostModel>? posts,
    bool? isLoading,
    bool? hasMore,
    String? error,
    bool? clearPosts = false,
    PostCategory? selectedCategory,
  }) {
    if (!mounted) return;

    setState(() {
      if (clearPosts == true) _posts.clear();
      if (posts != null) _posts = posts;
      if (isLoading != null) _isLoading = isLoading;
      if (hasMore != null) _hasMore = hasMore;
      if (error != null) _error = error;
      if (selectedCategory != null) _selectedCategory = selectedCategory;
    });
  }

  // Loading progress
  // Removed unused _loadingProgress field

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.filterCategory;
    _setupScrollListener();

    // Show loading state initially for better UX
    _updateFeedState(isLoading: true);

    // Initialize with proper auth loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWithAuth();
    });
  }

  Future<void> _initializeWithAuth() async {
    // Load current user with retry mechanism
    await _loadCurrentUserWithRetry();

    // ✅ FIX: Add subscription fallback for reliability
    if (_enableRealTimeUpdates) {
      try {
        _setupRealTimeSubscription();

        // Fallback: Load manually if subscription doesn't deliver data quickly
        await Future.delayed(const Duration(seconds: 2));
        if (_posts.isEmpty && mounted) {
          // debugPrint(
          //     'ShowcaseFeedScreen: Subscription fallback - loading manually');
          await _smartRefresh();
        }
      } catch (e) {
        debugPrint(
            'ShowcaseFeedScreen: Subscription setup error - using fallback: $e');
        if (mounted) {
          await _smartRefresh();
        }
      }
    } else {
      await _smartRefresh();
    }
  }

  // REMOVED: Unused methods _initializeDataLoading and _preloadData to eliminate duplicate API calls

  /// Setup real-time subscription with smart management
  void _setupRealTimeSubscription() {
    // ✅ FIX: Always cancel existing subscription first to prevent stuck flag
    _postsSubscription?.cancel();
    _isSubscriptionActive = false;

    // debugPrint(
    //     'ShowcaseFeedScreen: Setting up smart real-time subscription...');

    try {
      _isSubscriptionActive = true;

      // Setup ULTRA-FAST real-time subscription - OPTIMIZED for 5-second refresh
      _postsSubscription = _showcaseService
          .getShowcasePostsRealtimeStream(
        limit: 6, // Slightly larger batch for better content variety
        category: _selectedCategory,
      )
          .listen(
        (posts) {
          // Log logic removed

          if (mounted) {
            // SMART UPDATE: Only rebuild UI if data actually changed
            final hasChanges = _posts.length != posts.length ||
                _posts.asMap().entries.any((entry) {
                  final index = entry.key;
                  final oldPost = entry.value;
                  final newPost = index < posts.length ? posts[index] : null;

                  return newPost == null ||
                      oldPost.id != newPost.id ||
                      oldPost.likes.length != newPost.likes.length ||
                      oldPost.comments.length != newPost.comments.length ||
                      oldPost.reactions != newPost.reactions;
                });

            if (hasChanges || _posts.isEmpty) {
              // debugPrint(
              //     'ShowcaseFeedScreen: 🔄 Real-time changes detected - updating UI');
              setState(() {
                _posts = posts;
                _isLoading = false; // Force loading state to false
                _hasMore = posts.length >= _postsPerPage;
                _error = null;
              });

              // Only log feed update every 20th time
              // if (_updateCount % 20 == 1) {
              //   debugPrint(
              //       'ShowcaseFeedScreen: Feed updated with ${posts.length} posts [Update #$_updateCount] - Loading dismissed');
              // }
            } else {
              // debugPrint(
              //     'ShowcaseFeedScreen: No real-time changes detected - UI stays the same');
            }
          }
        },
        onError: (error) {
          debugPrint(
              'ShowcaseFeedScreen: Ultra-fast real-time subscription error: $error');
          _isSubscriptionActive = false; // Reset flag on error
          if (mounted) {
            _updateFeedState(
              error: error.toString(),
              isLoading: false,
            );
          }
        },
        onDone: () {
          _isSubscriptionActive = false; // Reset flag when subscription ends
          // debugPrint('ShowcaseFeedScreen: Real-time subscription ended');
          // Smart fallback - only if no posts loaded
          if (_posts.isEmpty && mounted) {
            _smartRefresh(); // Remove await from onDone callback
          }
        },
      );
    } catch (e) {
      _isSubscriptionActive = false; // Reset flag on exception
      debugPrint('ShowcaseFeedScreen: Error setting up subscription: $e');
      // Smart fallback - only if no posts loaded and mounted
      if (_posts.isEmpty && mounted) {
        _smartRefresh(); // Remove await from catch block
      }
    }
  }

  /// Smart manual refresh to prevent redundant calls
  void refreshFeed() {
    // debugPrint('ShowcaseFeedScreen: Smart manual refresh requested');

    if (_enableRealTimeUpdates) {
      // Real-time mode - setup subscription (handles internal checks)
      _setupRealTimeSubscription();
    } else {
      // Manual mode - use smart refresh
      _smartRefresh(clearPosts: true); // Remove await from void method
    }
  }

  /// Smart refresh with priority system
  Future<void> _refreshFeedWithLoading() async {
    // debugPrint('ShowcaseFeedScreen: Smart refresh initiated');

    _updateFeedState(
      isLoading: true,
      error: null,
    );

    // Smart refresh - use existing subscription if active, otherwise load directly
    if (_enableRealTimeUpdates && _isSubscriptionActive) {
      // Real-time subscription is active - just wait for natural update
      await Future.delayed(const Duration(milliseconds: 100));
    } else {
      // Load directly without redundant calls
      await _loadInitialPosts();
    }
  }

  /// Smart priority loading system - replaces redundant methods
  Future<void> _smartRefresh({bool clearPosts = false}) async {
    // debugPrint(
    //     'ShowcaseFeedScreen: Smart refresh initiated (clear: $clearPosts)');

    if (clearPosts) {
      _updateFeedState(
        clearPosts: true,
        isLoading: true,
        error: null,
        hasMore: true,
      );
    } else {
      _updateFeedState(isLoading: true, error: null);
    }

    try {
      // Priority 1: Use real-time subscription if enabled and active
      if (_enableRealTimeUpdates) {
        if (!_isSubscriptionActive) {
          _setupRealTimeSubscription();
        }
        // Let subscription handle the data loading
        return;
      }

      // Priority 2: Direct API call for manual mode
      final posts = await _showcaseService
          .getShowcasePosts(
            limit: _postsPerPage,
            category: _selectedCategory,
          )
          .timeout(const Duration(seconds: 10)); // Reasonable timeout

      if (mounted) {
        _updateFeedState(
          posts: posts,
          isLoading: false,
          hasMore: posts.length >= _postsPerPage,
        );
      }
    } catch (e) {
      debugPrint('ShowcaseFeedScreen: Smart refresh error: $e');
      if (mounted) {
        _updateFeedState(
          error: e.toString(),
          isLoading: false,
        );
      }
    }
  }

  /// Force refresh feed by calling backend API directly (ultra-fast)
  Future<void> forceRefreshFeed() async {
    // debugPrint('ShowcaseFeedScreen: Ultra-fast force refreshing feed...');
    // debugPrint(
    //     'ShowcaseFeedScreen: Current posts before refresh: ${_posts.length}');

    setState(() {
      _isLoading = true;
      _error = null;
      _posts.clear(); // Clear existing posts immediately
    });

    try {
      // Cancel existing subscription to prevent memory leaks
      await _postsSubscription?.cancel();
      _isSubscriptionActive = false;

      // Load posts directly from backend using the ultra-optimized method with ultra-fast timeout
      final posts = await _showcaseService
          .getShowcasePosts(
            limit: _postsPerPage,
            category: _selectedCategory,
          )
          .timeout(const Duration(
              seconds: 3)); // Ultra-fast timeout (reduced from 4 to 3 seconds)
      // debugPrint(
      //     'ShowcaseFeedScreen: Ultra-fast force refresh got ${posts.length} posts');

      if (posts.isNotEmpty) {
        // debugPrint(
        //     'ShowcaseFeedScreen: First post data: ${posts.first.id} - ${posts.first.content.substring(0, posts.first.content.length > 20 ? 20 : posts.first.content.length)}...');
        // debugPrint(
        //     'ShowcaseFeedScreen: Last post data: ${posts.last.id} - ${posts.last.content.substring(0, posts.last.content.length > 20 ? 20 : posts.last.content.length)}...');
      }

      // debugPrint(
      //     'ShowcaseFeedScreen: Ultra-fast force refresh successfully received ${posts.length} posts');

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          _hasMore = posts.length >= _postsPerPage;
        });
        // debugPrint(
        //     'ShowcaseFeedScreen: State updated with ${_posts.length} posts');
      }

      // Re-setup real-time subscription only if enabled
      if (_enableRealTimeUpdates) {
        _setupRealTimeSubscription();
      }
    } catch (e) {
      debugPrint('ShowcaseFeedScreen: Ultra-fast force refresh error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postsSubscription?.cancel();
    _postsSubscription = null;
    _isSubscriptionActive = false; // Reset subscription flag
    super.dispose();
  }

  // REMOVED: _loadCurrentUser - replaced with _loadCurrentUserWithRetry

  Future<void> _loadCurrentUserWithRetry() async {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);

    // Try up to 3 times with delay
    for (int i = 0; i < 3; i++) {
      _currentUser = authService.currentUser;
      // debugPrint(
      //     '🔄 ShowcaseFeedScreen: Retry $i - Current user: ${_currentUser?.uid ?? "NULL"}');

      if (_currentUser != null) {
        // debugPrint('✅ ShowcaseFeedScreen: Current user loaded successfully');
        break;
      }

      // Wait and try again
      await Future.delayed(Duration(milliseconds: 500 * (i + 1)));

      // Force reload auth service
      try {
        await authService.initialize();
      } catch (e) {
        debugPrint('⚠️ ShowcaseFeedScreen: Auth service init error: $e');
      }
    }

    if (_currentUser == null) {
      debugPrint(
          '❌ ShowcaseFeedScreen: Failed to load current user after retries');
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) {
          _loadMorePosts();
        }
      }
    });
  }

  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;

    _updateFeedState(
      isLoading: true,
      error: null,
      clearPosts: true,
      hasMore: true,
      // Reset progress removed
    );

    try {
      // Cancel and reset subscription state
      _postsSubscription?.cancel();
      _isSubscriptionActive = false;

      // Update progress to show loading started
      // Progress tracking removed for simplicity

      // Use ultra-optimized method with service-level timeout for homepage
      final posts = await _showcaseService
          .getShowcasePosts(
            limit: _postsPerPage,
            category: _selectedCategory,
          )
          .timeout(const Duration(
              seconds: 15)); // Add reasonable timeout for better UX

      // Update progress to show data loaded
      if (mounted) {
        // Progress tracking removed for simplicity
      }

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          _hasMore = posts.length >= _postsPerPage;
          // Progress tracking removed
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          // Progress tracking removed
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    _updateFeedState(isLoading: true);

    try {
      // For now, just reload all posts since backend doesn't support pagination yet
      final allPosts = await _showcaseService.getShowcasePosts(
        limit: _postsPerPage * 2, // Get more posts for pagination
        category: _selectedCategory,
      );

      // Simple pagination simulation - skip already loaded posts
      final newPosts =
          allPosts.skip(_posts.length).take(_postsPerPage).toList();

      if (mounted) {
        // Add new posts to existing posts
        final updatedPosts = List<ShowcasePostModel>.from(_posts)
          ..addAll(newPosts);
        _updateFeedState(
          posts: updatedPosts,
          isLoading: false,
          hasMore: newPosts.length >= _postsPerPage,
        );
      }
    } catch (e) {
      if (mounted) {
        _updateFeedState(
          error: e.toString(),
          isLoading: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      color: Colors.transparent,
      child: _buildBody(),
    );
  }

  /// Navigate to post creation with callback to refresh feed
  void _navigateToPostCreation() async {
    debugPrint('ShowcaseFeedScreen: Navigating to post creation...');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PostCreationScreen(),
      ),
    );

    debugPrint('ShowcaseFeedScreen: Post creation screen returned: $result');

    // Check if post was created successfully
    if (result == true) {
      debugPrint(
          'ShowcaseFeedScreen: Post creation completed, refreshing feed...');
      debugPrint('ShowcaseFeedScreen: Current posts count: ${_posts.length}');
      debugPrint('ShowcaseFeedScreen: Calling forceRefreshFeed()...');

      // Add a small delay to ensure database has processed the new post (reduced)
      await Future.delayed(
          const Duration(milliseconds: 500)); // Reduced from 1000ms to 500ms

      // Force a complete refresh
      await forceRefreshFeed();
      debugPrint(
          'ShowcaseFeedScreen: forceRefreshFeed() completed. New posts count: ${_posts.length}');
    } else {
      debugPrint(
          'ShowcaseFeedScreen: Post creation did not return true, result: $result');
    }
  }

  Widget _buildBody() {
    if (_posts.isEmpty && _isLoading) {
      return _buildLoadingState();
    }

    if (_posts.isEmpty && !_isLoading && _error == null) {
      return RefreshIndicator(
        onRefresh: _refreshFeedWithLoading,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(),
          ),
        ),
      );
    }

    if (_posts.isEmpty && _error != null) {
      return _buildErrorState();
    }

    return custom_refresh.EnhancedRefreshIndicator(
      onRefresh: _refreshFeedWithLoading,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Category filters removed - not needed for MVP

          // Posts list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < _posts.length) {
                    final post = _posts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: GlassShowcaseCard(
                        post: post,
                        onTap: () => _handlePostTap(post),
                        onLike: () async {
                          // Optimistic update handled by card, logical update via service
                          if (_currentUser != null) {
                            await _showcaseService.toggleLike(
                                post.id, _currentUser!.id);
                          }
                        },
                        onComment: () => _handlePostTap(post),
                      ),
                    );
                  } else if (_hasMore) {
                    return _buildLoadingIndicator();
                  }
                  return const SizedBox(height: 80); // Bottom padding
                },
                childCount: _posts.length + (_hasMore ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Category filter chips removed - not needed for MVP

  Widget _buildLoadingState() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Loading header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              children: [
                // Compact loading indicator
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      Text(
                        'Loading showcase...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Shimmer skeleton loading cards
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SkeletonPostCard(),
              );
            },
            childCount: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load posts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialPosts,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space2xl),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              'Ready to Shine?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: null, // Use theme default
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Share your talents, achievements, and connect with the UTHM community!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: null, // Use theme default
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  debugPrint(
                      'ShowcaseFeedScreen: Post creation button pressed');
                  _navigateToPostCreation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg,
                    vertical: AppTheme.spaceMd,
                  ),
                ),
                icon: Icon(Icons.add_rounded,
                    color: Theme.of(context).colorScheme.onPrimary),
                label: Text(
                  'Create Your First Post',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              'Loading more posts...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation and interaction methods

  void _handlePostTap(ShowcasePostModel post) {
    _navigateToPostDetail(post);
  }

  void _navigateToPostDetail(ShowcasePostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          postId: post.id,
          initialPost: post,
        ),
      ),
    ).then((_) {
      // Refresh list when returning just in case interactions happened
      _refreshSpecificPost(post.id);
    });
  }

  /// Refresh a specific post in the feed (or remove if deleted)
  Future<void> _refreshSpecificPost(String postId) async {
    try {
      // Get updated post data
      final updatedPost = await _showcaseService.getPostById(postId);

      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == postId);
          if (index != -1) {
            if (updatedPost != null) {
              // ✅ Post exists - update it
              _posts[index] = updatedPost;
              debugPrint('ShowcaseFeedScreen: Refreshed post $postId in feed');
            } else {
              // ✅ FIX: Post was deleted - remove from list
              _posts.removeAt(index);
              debugPrint(
                  'ShowcaseFeedScreen: Removed deleted post $postId from feed');
            }
          }
        });
      }
    } catch (e) {
      debugPrint('ShowcaseFeedScreen: Error refreshing post $postId: $e');
    }
  }

  /// Update a specific post in the feed (for external updates)
  void updatePostInFeed(ShowcasePostModel updatedPost) {
    if (mounted) {
      setState(() {
        final index = _posts.indexWhere((p) => p.id == updatedPost.id);
        if (index != -1) {
          _posts[index] = updatedPost;
        }
      });
      debugPrint('ShowcaseFeedScreen: Updated post ${updatedPost.id} in feed');
    }
  }
}
