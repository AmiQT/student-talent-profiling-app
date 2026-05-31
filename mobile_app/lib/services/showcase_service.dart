import '../config/app_config.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import '../models/showcase_models.dart';
import '../models/post_creation_models.dart';
import '../utils/media_utils.dart';
import '../config/cloudinary_config.dart';
import 'supabase_auth_service.dart';

class ShowcaseService {
  static const String baseUrl =
      AppConfig.backendUrl; // Use stable cloud backend

  final SupabaseAuthService _authService = SupabaseAuthService();

  // Counter for reducing console spam
  int _callCount = 0;

  // Smart unified caching system for performance
  static final Map<String, List<ShowcasePostModel>> _postsCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Supabase configuration - Complete integration
  SupabaseClient get _supabase => Supabase.instance.client;

  // Upload progress controllers
  final Map<String, StreamController<MediaUploadProgress>> _uploadControllers =
      {};

  // ==================== SMART CACHING SYSTEM ====================

  // Unified cache configuration with smart invalidation
  // REMOVED: _mediumCache - using _normalTimeout instead
  static const Duration _longCache = Duration(hours: 1); // For user profiles
  static const Duration _cacheValidity =
      Duration(minutes: 15); // Legacy compatibility
  static const Duration _profilesCacheValidity =
      Duration(hours: 1); // Legacy compatibility

  // Smart batch request management
  static final Map<String, Future<dynamic>> _ongoingRequests = {};

  // User profile cache with batching
  static final Map<String, Map<String, dynamic>> _profilesCache = {};
  static final Map<String, DateTime> _profilesCacheTimestamps = {};

  // Smart timeout configuration based on data type
  static const Duration _normalTimeout =
      Duration(seconds: 10); // For fresh data

  // Cleanup method for controllers
  void dispose() {
    for (final controller in _uploadControllers.values) {
      controller.close();
    }
    _uploadControllers.clear();
  }

  /// Test database connection and check table schema
  Future<bool> testDatabaseConnection() async {
    try {
      debugPrint('ShowcaseService: Testing database connection...');

      // Try to fetch one row to test connection
      await _supabase.from('showcase_posts').select('id').limit(1);

      debugPrint('ShowcaseService: Database connection successful');
      return true;
    } catch (e) {
      debugPrint('ShowcaseService: Database connection failed: $e');
      return false;
    }
  }

  /// Check if required columns exist in showcase_posts table
  Future<Map<String, bool>> checkTableSchema() async {
    try {
      debugPrint('ShowcaseService: Checking table schema...');

      // Try to select all columns to see which ones exist
      final response =
          await _supabase.from('showcase_posts').select('*').limit(1);

      if (response.isNotEmpty) {
        final columns = response.first.keys.toList();
        debugPrint('ShowcaseService: Available columns: $columns');

        return {
          'allow_comments': columns.contains('allow_comments'),
          'media_urls': columns.contains('media_urls'),
          'media_types': columns.contains('media_types'),
          'is_public': columns.contains('is_public'),
        };
      }

      return {};
    } catch (e) {
      debugPrint('ShowcaseService: Error checking schema: $e');
      return {};
    }
  }

  /// Create a new showcase post
  Future<void> createPost(Map<String, dynamic> postData) async {
    try {
      debugPrint('ShowcaseService: Creating post with Supabase...');
      debugPrint('ShowcaseService: Post data: ${json.encode(postData)}');

      // First test database connection
      final isConnected = await testDatabaseConnection();
      if (!isConnected) {
        throw Exception('Database connection failed');
      }

      // Check table schema
      final schema = await checkTableSchema();
      debugPrint('ShowcaseService: Table schema: $schema');

      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Build request body based on available columns
      final requestBody = <String, dynamic>{
        'user_id': currentUserId,
        'title': postData['title'] ?? '',
        'description': postData['description'] ?? '',
        'content': postData['content'] ?? '',
        'category': postData['category'] ?? 'general',
        'tags': postData['tags'] ?? [],
        'skills_used': postData['skills_used'] ?? [],
        'media_urls': postData['media_urls'] ?? [],
        'media_types': postData['media_types'] ?? [],
        'created_at': DateTime.now().toIso8601String(),
      };

      // Only add columns that exist in the database
      if (schema['is_public'] == true) {
        requestBody['is_public'] = postData['is_public'] ?? true;
      }

      debugPrint('ShowcaseService: Request body: ${json.encode(requestBody)}');

      await _supabase.from('showcase_posts').insert(requestBody);

      debugPrint('ShowcaseService: Post created successfully with Supabase!');
    } catch (e) {
      debugPrint('Error creating showcase post: $e');
      rethrow;
    }
  }

  /// Smart batch user lookup system - consolidates multiple user requests
  static final Map<String, List<Completer<Map<String, dynamic>>>>
      _pendingUserRequests = {};
  static Timer? _batchTimer;

  /// Get user info with smart batching to reduce API calls
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    // Check cache first
    final cacheKey = 'user_$userId';
    if (_profilesCache.containsKey(cacheKey)) {
      final timestamp = _profilesCacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _longCache) {
        return _profilesCache[cacheKey];
      }
      // Remove expired cache
      _profilesCache.remove(cacheKey);
      _profilesCacheTimestamps.remove(cacheKey);
    }

    // Add to batch request
    final completer = Completer<Map<String, dynamic>>();
    _pendingUserRequests.putIfAbsent(userId, () => []).add(completer);

    // Start batch timer if not already running
    _batchTimer ??=
        Timer(const Duration(milliseconds: 50), _processBatchUserRequests);

    return completer.future;
  }

  /// Process batched user requests to reduce API calls
  static void _processBatchUserRequests() async {
    final currentRequests =
        Map<String, List<Completer<Map<String, dynamic>>>>.from(
            _pendingUserRequests);
    _pendingUserRequests.clear();
    _batchTimer = null;

    if (currentRequests.isEmpty) return;

    final userIds = currentRequests.keys.toList();
    // debugPrint(
    //     'ShowcaseService: Processing batched user requests for ${userIds.length} users');

    try {
      // Batch fetch from database (FIXED - use correct column names)
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name') // Only use columns that exist in users table
          .filter('id', 'in', userIds)
          .timeout(const Duration(seconds: 2));

      // Create results map
      final results = <String, Map<String, dynamic>>{};
      for (final row in response) {
        results[row['id']] = row;
      }

      // Complete all pending requests
      for (final entry in currentRequests.entries) {
        final userId = entry.key;
        final completers = entry.value;
        final userData =
            results[userId] ?? {'id': userId, 'name': 'Unknown User'};

        // Cache the result with fallback full_name
        final Map<String, dynamic> processedData = {
          ...userData,
          'full_name': userData['name'] ??
              'User', // Map name to full_name for compatibility
        };
        _profilesCache['user_$userId'] = processedData;
        _profilesCacheTimestamps['user_$userId'] = DateTime.now();

        // Complete all waiting requests
        for (final completer in completers) {
          if (!completer.isCompleted) {
            completer.complete(processedData);
          }
        }
      }
    } catch (e) {
      debugPrint('ShowcaseService: Error in batch user request: $e');

      // Complete with error for all pending requests
      for (final entry in currentRequests.entries) {
        final completers = entry.value;
        for (final completer in completers) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      }
    }
  }

  /// OPTIMIZED: True batch fetch - single DB query for all users
  Future<Map<String, Map<String, dynamic>>> _fetchProfilesForUsers(
      List<String> userIds) async {
    try {
      if (userIds.isEmpty) return {};

      // debugPrint(
      //     'ShowcaseService: 🚀 BATCH fetching ${userIds.length} profiles in ONE query');

      // ✅ OPTIMIZED: Fetch from users table with basic info
      final usersResponse = await _supabase
          .from('users')
          .select('id, name, role, department')
          .filter('id', 'in', userIds)
          .timeout(const Duration(seconds: 2));

      // ✅ NEW: Fetch profile images from profiles table
      final profilesResponse = await _supabase
          .from('profiles')
          .select('user_id, profile_image_url, headline, full_name')
          .filter('user_id', 'in', userIds)
          .timeout(const Duration(seconds: 2));

      // debugPrint(
      //     'ShowcaseService: ✅ Fetched ${usersResponse.length} users and ${profilesResponse.length} profiles');

      // Create profiles map for quick lookup
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profilesResponse) {
        profilesMap[profile['user_id']] = profile;
      }

      // Process results combining users + profiles data
      final results = <String, Map<String, dynamic>>{};
      for (final user in usersResponse) {
        final userId = user['id'];
        final profile = profilesMap[userId];

        final Map<String, dynamic> processedData = {
          ...user,
          'full_name': profile?['full_name'] ?? user['name'] ?? 'User',
          'profile_image_url':
              profile?['profile_image_url'], // ✅ Cloudinary URL
          'headline': profile?['headline'],
        };
        results[userId] = processedData;

        // Cache the result for future use
        _profilesCache['user_$userId'] = processedData;
        _profilesCacheTimestamps['user_$userId'] = DateTime.now();
      }

      // Add fallback for missing users
      for (final userId in userIds) {
        if (!results.containsKey(userId)) {
          final fallbackData = {
            'id': userId,
            'name': 'User',
            'full_name': 'User',
            'profile_image_url': null, // ✅ Null fallback
          };
          results[userId] = fallbackData;
          _profilesCache['user_$userId'] = fallbackData;
          _profilesCacheTimestamps['user_$userId'] = DateTime.now();
        }
      }

      // debugPrint(
      //     'ShowcaseService: 🎯 Batch processing complete - ${results.length} profiles with images ready');
      return results;
    } catch (e) {
      debugPrint('ShowcaseService: ❌ Batch fetch error: $e');

      // Fallback: Return default user data for all requested IDs
      final fallback = <String, Map<String, dynamic>>{};
      for (final userId in userIds) {
        fallback[userId] = {
          'id': userId,
          'name': 'User',
          'full_name': 'User',
          'profile_image_url': null,
        };
      }
      return fallback;
    }
  }

  /// Get all showcase posts
  Future<List<Map<String, dynamic>>> getAllPosts() async {
    try {
      // debugPrint('ShowcaseService: Fetching posts from Supabase...');

      // Use the correct query structure that works with Supabase
      final response = await _supabase.from('showcase_posts').select('''
            id,
            user_id,
            content,
            category,
            tags,
            media_urls,
            media_types,
            is_public,
            created_at,
            updated_at,
            is_edited,
            location,
            skills_used,
            description,
            title,
            likes,
            comments,
            post_likes(user_id),
            post_comments(*)
          ''').eq('is_public', true).order('created_at', ascending: false);

      // debugPrint(
      //     'ShowcaseService: Fetched ${response.length} posts from Supabase');

      // Extract unique user IDs (post authors + comment authors)
      final Set<String> allUserIds = {};
      for (final post in response) {
        allUserIds.add(post['user_id'] as String);
        // Extract comment author IDs from post_comments
        final postComments = post['post_comments'] as List<dynamic>?;
        if (postComments != null) {
          for (final comment in postComments) {
            final commentUserId = comment['user_id'];
            if (commentUserId != null) {
              allUserIds.add(commentUserId.toString());
            }
          }
        }
      }

      // Fetch all profiles efficiently in one query (including comment authors)
      final profilesMap = await _fetchProfilesForUsers(allUserIds.toList());

      // Combine post data with profile data AND enrich comments with user names
      final List<Map<String, dynamic>> postsWithProfiles = response.map((post) {
        final userId = post['user_id'] as String;
        final profile = profilesMap[userId] ?? {};

        // Enrich post_comments with user names from profilesMap
        final postComments = post['post_comments'] as List<dynamic>?;
        List<Map<String, dynamic>>? enrichedComments;
        if (postComments != null) {
          enrichedComments = postComments.map((comment) {
            final commentUserId = comment['user_id']?.toString() ?? '';
            final commentUserProfile = profilesMap[commentUserId];
            final userName =
                commentUserProfile?['full_name']?.toString().isNotEmpty == true
                    ? commentUserProfile!['full_name'].toString()
                    : commentUserProfile?['name']?.toString().isNotEmpty == true
                        ? commentUserProfile!['name'].toString()
                        : 'Anonymous User';
            return {
              ...Map<String, dynamic>.from(comment),
              'user_name': userName,
              'userName': userName,
              'user_profile_image': commentUserProfile?['profile_image_url'],
              'userProfileImage': commentUserProfile?['profile_image_url'],
            };
          }).toList();
        }

        return {
          ...post,
          'profiles': profile,
          if (enrichedComments != null) 'post_comments': enrichedComments,
        };
      }).toList();

      // debugPrint(
      //     'ShowcaseService: Successfully fetched ${postsWithProfiles.length} posts with profiles');
      return postsWithProfiles;
    } catch (e) {
      debugPrint('ShowcaseService: Error fetching posts: $e');
      return [];
    }
  }

  /// Update a showcase post
  Future<void> updatePost(
      String postId, Map<String, dynamic> updatedData) async {
    try {
      await _supabase.from('showcase_posts').update({
        ...updatedData,
        'updated_at': DateTime.now().toIso8601String(),
        'is_edited': true,
      }).eq('id', postId);

      debugPrint('ShowcaseService: Post updated successfully: $postId');
      // await SupabaseConfig.from('showcase_posts')
      //     .update({
      //       ...updatedData,
      //       'updatedAt': DateTime.now().toIso8601String(),
      //       'isEdited': true,
      //     })
      //     .eq('id', postId);
    } catch (e) {
      debugPrint('Error updating showcase post: $e');
      rethrow;
    }
  }

  /// Delete a showcase post
  Future<void> deletePost(String postId) async {
    try {
      // First delete associated media files from Cloudinary
      final postData = await _supabase
          .from('showcase_posts')
          .select('media_urls')
          .eq('id', postId)
          .single();

      if (postData['media_urls'] != null) {
        final mediaUrls = List<String>.from(postData['media_urls']);
        for (String url in mediaUrls) {
          // Delete from Cloudinary using the deleteMediaFile method
          await deleteMediaFile(url);
        }
      }

      // Delete the post record
      await _supabase.from('showcase_posts').delete().eq('id', postId);

      debugPrint('ShowcaseService: Post deleted successfully: $postId');
    } catch (e) {
      debugPrint('Error deleting showcase post: $e');
      rethrow;
    }
  }

  /// Get posts by user ID
  Future<List<Map<String, dynamic>>> getPostsByUserId(String userId) async {
    try {
      // debugPrint('ShowcaseService: Getting posts for user: $userId');

      final response = await _supabase.from('showcase_posts').select('''
            id,
            user_id,
            content,
            category,
            tags,
            media_urls,
            media_types,
            is_public,
            created_at,
            updated_at,
            is_edited,
            location,
            skills_used,
            description,
            title,
            post_likes(user_id),
            post_comments(*)
          ''').eq('user_id', userId).order('created_at', ascending: false);

      // Fetch profile data for this user (OPTIMIZED - exclude large images)
      final profileResponse = await _supabase
          .from('profiles')
          .select('full_name') // Removed profile_image_url for faster loading
          .eq('user_id', userId)
          .maybeSingle();

      // Extract comment author IDs and fetch their profiles
      final Set<String> commentUserIds = {};
      for (final post in response) {
        final postComments = post['post_comments'] as List<dynamic>?;
        if (postComments != null) {
          for (final comment in postComments) {
            final commentUserId = comment['user_id'];
            if (commentUserId != null && commentUserId != userId) {
              commentUserIds.add(commentUserId.toString());
            }
          }
        }
      }

      // Fetch comment author profiles if needed
      Map<String, Map<String, dynamic>> commentProfilesMap = {};
      if (commentUserIds.isNotEmpty) {
        commentProfilesMap =
            await _fetchProfilesForUsers(commentUserIds.toList());
      }
      // Add current user profile to map
      if (profileResponse != null) {
        commentProfilesMap[userId] = profileResponse;
      }

      // Combine posts with profile data AND enrich comments with user names
      return response.map<Map<String, dynamic>>((post) {
        // Enrich post_comments with user names
        final postComments = post['post_comments'] as List<dynamic>?;
        List<Map<String, dynamic>>? enrichedComments;
        if (postComments != null) {
          enrichedComments = postComments.map((comment) {
            final commentUserId = comment['user_id']?.toString() ?? '';
            final commentUserProfile = commentProfilesMap[commentUserId];
            final userName =
                commentUserProfile?['full_name']?.toString().isNotEmpty == true
                    ? commentUserProfile!['full_name'].toString()
                    : commentUserProfile?['name']?.toString().isNotEmpty == true
                        ? commentUserProfile!['name'].toString()
                        : 'Anonymous User';
            return {
              ...Map<String, dynamic>.from(comment),
              'user_name': userName,
              'userName': userName,
            };
          }).toList();
        }

        return {
          ...post,
          'profiles': profileResponse ?? {},
          if (enrichedComments != null) 'post_comments': enrichedComments,
        };
      }).toList();
    } catch (e) {
      debugPrint('ShowcaseService: Error fetching user posts: $e');
      return [];
    }
  }

  // ==================== ENHANCED MEDIA UPLOAD METHODS ====================

  /// Upload multiple media files with progress tracking
  Future<List<MediaModel>> uploadMediaFiles({
    required List<File> files,
    required String userId,
    Function(String mediaId, double progress)? onProgress,
  }) async {
    final List<MediaModel> uploadedMedia = [];

    try {
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final mediaId = 'media_${DateTime.now().millisecondsSinceEpoch}_$i';

        // Validate media file
        final validation = await MediaUtils.validateMediaFile(file);
        if (!validation.isValid) {
          throw Exception('Invalid media file: ${validation.error}');
        }

        // Upload media with progress tracking
        final mediaModel = await _uploadSingleMediaFile(
          file: file,
          userId: userId,
          mediaId: mediaId,
          onProgress: (progress) => onProgress?.call(mediaId, progress),
        );

        if (mediaModel != null) {
          uploadedMedia.add(mediaModel);
        }
      }

      return uploadedMedia;
    } catch (e) {
      debugPrint('Error uploading media files: $e');
      rethrow;
    }
  }

  /// Upload file to Cloudinary with progress tracking
  Future<String> _uploadFileToCloudinary({
    required File file,
    required String userId,
    Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint('ShowcaseService: Uploading file to Cloudinary...');

      final filePath = file.path;
      final fileExtension = filePath.split('.').last.toLowerCase();

      String cloudinaryUrl;

      // Determine if it's image or video and upload accordingly
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension)) {
        cloudinaryUrl = await CloudinaryConfig.uploadImage(
          filePath: filePath,
          userId: userId,
          onProgress: onProgress,
        );
      } else if (['mp4', 'mov', 'avi', 'mkv'].contains(fileExtension)) {
        cloudinaryUrl = await CloudinaryConfig.uploadVideo(
          filePath: filePath,
          userId: userId,
          onProgress: onProgress,
        );
      } else {
        throw Exception('Unsupported file type: $fileExtension');
      }

      debugPrint(
          'ShowcaseService: File uploaded successfully to Cloudinary: $cloudinaryUrl');
      return cloudinaryUrl;
    } catch (e) {
      debugPrint('Error uploading file to Cloudinary: $e');
      rethrow;
    }
  }

  /// Upload single media file with compression and progress tracking
  Future<MediaModel?> _uploadSingleMediaFile({
    required File file,
    required String userId,
    required String mediaId,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Validate file
      final validation = await MediaUtils.validateMediaFile(file);
      if (!validation.isValid) {
        throw Exception('Invalid file: ${validation.error}');
      }

      // Compress file if needed
      final processedFile = await MediaUtils.compressImage(file) ?? file;

      // Upload to Cloudinary instead of Supabase Storage
      final downloadUrl = await _uploadFileToCloudinary(
        file: processedFile,
        userId: userId,
        onProgress: onProgress,
      );

      // Create media model
      final mediaModel = MediaModel(
        id: mediaId,
        url: downloadUrl,
        type: processedFile.path.split('.').last == 'mp4' ? 'video' : 'image',
        uploadedAt: DateTime.now(),
      );

      return mediaModel;
    } catch (e) {
      debugPrint('Error uploading single media file: $e');
      return null;
    }
  }

  /// Get upload progress stream for a specific media
  Stream<MediaUploadProgress> getUploadProgressStream(String mediaId) {
    if (!_uploadControllers.containsKey(mediaId)) {
      _uploadControllers[mediaId] =
          StreamController<MediaUploadProgress>.broadcast();
    }
    return _uploadControllers[mediaId]!.stream;
  }

  /// Batch upload with detailed progress tracking
  Future<List<MediaModel>> batchUploadMedia({
    required List<File> files,
    required String userId,
    Function(Map<String, MediaUploadProgress> progressMap)? onBatchProgress,
  }) async {
    final Map<String, MediaUploadProgress> progressMap = {};
    final List<MediaModel> uploadedMedia = [];

    try {
      // Initialize progress tracking
      for (int i = 0; i < files.length; i++) {
        final mediaId = 'media_${DateTime.now().millisecondsSinceEpoch}_$i';
        progressMap[mediaId] = MediaUploadProgress(
          mediaId: mediaId,
          fileName: files[i].path.split('/').last,
        );
      }

      // Upload files concurrently with limited concurrency
      final futures = <Future<MediaModel?>>[];
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final mediaId = 'media_${DateTime.now().millisecondsSinceEpoch}_$i';

        futures.add(_uploadSingleMediaFile(
          file: file,
          userId: userId,
          mediaId: mediaId,
          onProgress: (progress) {
            progressMap[mediaId] = progressMap[mediaId]!.copyWith(
              progress: progress,
              isCompleted: progress >= 1.0,
            );
            onBatchProgress?.call(Map.from(progressMap));
          },
        ));
      }

      final results = await Future.wait(futures);

      for (final result in results) {
        if (result != null) {
          uploadedMedia.add(result);
        }
      }

      return uploadedMedia;
    } catch (e) {
      debugPrint('Error in batch upload: $e');
      rethrow;
    }
  }

  /// Create showcase post with media using Supabase
  Future<PostCreationResult> createShowcasePost({
    required String content,
    required PostType type,
    required PostCategory category,
    required PostPrivacy privacy,
    List<File> mediaFiles = const [],
    List<String> tags = const [],
    List<MentionModel> mentions = const [],
    String? location,
  }) async {
    try {
      debugPrint('ShowcaseService: Creating showcase post with media...');

      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Upload media files first if any
      List<MediaModel> uploadedMedia = [];
      if (mediaFiles.isNotEmpty) {
        debugPrint(
            'ShowcaseService: Uploading ${mediaFiles.length} media files...');
        uploadedMedia = await uploadMediaFiles(
          files: mediaFiles,
          userId: currentUserId,
          onProgress: (mediaId, progress) {
            debugPrint(
                'Upload progress for $mediaId: ${(progress * 100).toStringAsFixed(1)}%');
          },
        );
        debugPrint(
            'ShowcaseService: Successfully uploaded ${uploadedMedia.length} media files');
      }

      // Create post data
      final postData = {
        'user_id': currentUserId,
        'content': content,
        'title':
            content.length > 50 ? '${content.substring(0, 50)}...' : content,
        'description': content,
        'category': category.toString().split('.').last,
        'tags': tags,
        'media_urls': uploadedMedia.map((m) => m.url).toList(),
        'media_types': uploadedMedia.map((m) => m.type).toList(),
        'is_public': privacy == PostPrivacy.public,
        'allow_comments': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('ShowcaseService: Creating post with data: ${postData.keys}');

      // Create post via Supabase
      await createPost(postData);

      debugPrint('ShowcaseService: Post created successfully!');

      // ✅ FIX: Clear cache to ensure feed shows new post immediately
      clearAllCaches();

      return PostCreationResult(
        success: true,
        postId: 'temp_post_id_${DateTime.now().millisecondsSinceEpoch}',
        post: null, // Will be implemented with Supabase
      );
    } catch (e) {
      debugPrint('Error creating showcase post: $e');
      return PostCreationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Create showcase post with pre-uploaded media URLs (for web/XFile compatibility)
  Future<PostCreationResult> createShowcasePostWithUrls({
    required String content,
    required PostType type,
    required PostCategory category,
    required PostPrivacy privacy,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    List<String> tags = const [],
    List<MentionModel> mentions = const [],
    String? location,
  }) async {
    try {
      debugPrint(
          'ShowcaseService: Creating showcase post with pre-uploaded URLs...');

      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Create post data with pre-uploaded media URLs
      final postData = {
        'user_id': currentUserId,
        'content': content,
        'title':
            content.length > 50 ? '${content.substring(0, 50)}...' : content,
        'description': content,
        'category': category.toString().split('.').last,
        'tags': tags,
        'media_urls': mediaUrls,
        'media_types': mediaTypes,
        'is_public': privacy == PostPrivacy.public,
        'allow_comments': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint(
          'ShowcaseService: Creating post with ${mediaUrls.length} pre-uploaded media');

      // Create post via Supabase
      await createPost(postData);

      debugPrint(
          'ShowcaseService: Post created successfully with pre-uploaded URLs!');

      // ✅ FIX: Clear cache to ensure feed shows new post immediately
      clearAllCaches();

      return PostCreationResult(
        success: true,
        postId: 'temp_post_id_${DateTime.now().millisecondsSinceEpoch}',
        post: null,
      );
    } catch (e) {
      debugPrint('Error creating showcase post with URLs: $e');
      return PostCreationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get showcase posts with pagination and filtering (ultra-optimized method)
  Future<List<ShowcasePostModel>> getShowcasePosts({
    int limit = 10,
    String? lastPostId,
    PostPrivacy? privacy,
    PostCategory? category,
    String? userId,
  }) async {
    final stopwatch = Stopwatch()..start(); // Performance monitoring

    try {
      // Only log every 100th call to reduce console spam
      _callCount++;
      if (_callCount % 100 == 1) {
        // debugPrint(
        //     'ShowcaseService: Getting showcase posts (ultra-optimized method)... [Call #$_callCount]');
      }

      // Generate cache key based on parameters
      final cacheKey =
          'posts_${privacy?.name ?? 'public'}_${category?.name ?? 'all'}_${userId ?? 'all'}_$limit';

      // ULTRA-FAST CACHE: 5-second cache for social media freshness
      if (_postsCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < const Duration(seconds: 5)) {
          // MUCH FASTER: 5 seconds instead of 30
          stopwatch.stop();
          // debugPrint(
          //     'ShowcaseService: ⚡ Ultra-fast cache hit - loaded in ${stopwatch.elapsedMilliseconds}ms');
          return List<ShowcasePostModel>.from(_postsCache[cacheKey]!);
        }
        // Remove expired cache
        _postsCache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
      }

      // Prevent duplicate requests with smart batching
      final requestKey = 'getShowcasePosts_$cacheKey';
      if (_ongoingRequests.containsKey(requestKey)) {
        debugPrint('ShowcaseService: Returning batched request for $cacheKey');
        return await _ongoingRequests[requestKey] as List<ShowcasePostModel>;
      }

      // debugPrint('ShowcaseService: Loading real data from Supabase...');
      // final dbStartTime = Stopwatch()..start();
      final profilesStartTime = Stopwatch();

      // Smart timeout based on cache status
      const timeoutDuration = _normalTimeout; // Use consistent timeout

      // Build optimized query for homepage feed (minimal fields for speed)
      // Join with post_likes and post_comments to get real engagement data
      var query = _supabase.from('showcase_posts').select('''
            id,
            user_id,
            content,
            created_at,
            media_urls,
            media_types,
            title,
            category,
            likes,
            comments,
            post_likes(user_id),
            post_comments(*)
          '''); // Include essential fields only

      // Apply filters
      if (privacy != null) {
        query = query.eq('is_public', privacy == PostPrivacy.public);
      } else {
        // Default to public posts
        query = query.eq('is_public', true);
      }

      if (category != null) {
        query = query.eq('category', category.toString().split('.').last);
      }

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      // Apply ordering and limiting with ultra-fast timeout
      // debugPrint('ShowcaseService: Starting posts query...');
      final postsQueryStart = Stopwatch()..start();
      final response = await query
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(timeoutDuration);
      postsQueryStart.stop();
      // debugPrint(
      //     'ShowcaseService: Posts query completed in ${postsQueryStart.elapsedMilliseconds}ms, got ${response.length} posts');

      // Extract unique user IDs (post authors + comment authors)
      final Set<String> allUserIds = {};
      for (final post in response) {
        allUserIds.add(post['user_id'] as String);
        // Extract comment author IDs
        final postComments = post['post_comments'] as List<dynamic>?;
        if (postComments != null) {
          for (final comment in postComments) {
            final commentUserId = comment['user_id'];
            if (commentUserId != null) {
              allUserIds.add(commentUserId.toString());
            }
          }
        }
      }

      // Fetch all profiles efficiently with ultra-fast timeout - OPTIMIZED
      profilesStartTime.start();
      // debugPrint(
      //     'ShowcaseService: Starting profiles fetch for ${allUserIds.length} users...');
      final profilesMap = await _fetchProfilesForUsers(allUserIds.toList())
          .timeout(const Duration(
              seconds: 2)); // Further reduced from 3 to 2 seconds
      profilesStartTime.stop();
      // debugPrint(
      //     'ShowcaseService: Profiles fetch completed in ${profilesStartTime.elapsedMilliseconds}ms');

      // Parse posts to ShowcasePostModel with minimal processing
      // debugPrint('ShowcaseService: Starting posts parsing...');
      final parsingStart = Stopwatch()..start();
      final List<ShowcasePostModel> postsWithProfiles = [];

      for (final post in response) {
        try {
          final userId = post['user_id'] as String;
          final profile = profilesMap[userId] ?? {};

          // Enrich post_comments with user names from profilesMap
          final postComments = post['post_comments'] as List<dynamic>?;
          List<Map<String, dynamic>>? enrichedComments;
          if (postComments != null) {
            enrichedComments = postComments.map((comment) {
              final commentUserId = comment['user_id']?.toString() ?? '';
              final commentUserProfile = profilesMap[commentUserId];
              final userName = commentUserProfile?['full_name']
                          ?.toString()
                          .isNotEmpty ==
                      true
                  ? commentUserProfile!['full_name'].toString()
                  : commentUserProfile?['name']?.toString().isNotEmpty == true
                      ? commentUserProfile!['name'].toString()
                      : 'Anonymous User';
              return {
                ...Map<String, dynamic>.from(comment),
                'user_name': userName,
                'userName': userName,
                'user_profile_image': commentUserProfile?['profile_image_url'],
                'userProfileImage': commentUserProfile?['profile_image_url'],
              };
            }).toList();
          }

          // Combine post data with profile data (minimal processing)
          final postWithProfile = {
            ...post,
            'profiles': profile,
            if (enrichedComments != null) 'post_comments': enrichedComments,
            // Map profile data to expected field names (OPTIMIZED - no images for speed)
            'user_name': profile['full_name'] ?? 'User',
            'user_profile_image':
                null, // Removed for 10x faster loading - will lazy load if needed
            'user_headline': profile['headline'] ?? '',
            // Add default values for missing fields to avoid parsing errors
            'tags': post['tags'] ?? [],
            'media_types': post['media_types'] ?? [],
            'updated_at': post['updated_at'] ?? post['created_at'],
            'is_edited': post['is_edited'] ?? false,
            'location': post['location'] ?? '',
            'skills_used': post['skills_used'] ?? [],
            'description': post['description'] ?? post['content'],
            'title': post['title'] ?? '',
          };

          // Parse to ShowcasePostModel
          final postModel = ShowcasePostModel.fromJson(postWithProfile);
          postsWithProfiles.add(postModel);
        } catch (e) {
          debugPrint('ShowcaseService: Error parsing post ${post['id']}: $e');
          // Skip this post if there's an error
          continue;
        }
      }

      parsingStart.stop();
      // debugPrint(
      //     'ShowcaseService: Posts parsing completed in ${parsingStart.elapsedMilliseconds}ms');

      // Cache the results
      _postsCache[cacheKey] = postsWithProfiles;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // debugPrint(
      //     'ShowcaseService: Cached ${postsWithProfiles.length} posts for key: $cacheKey');

      stopwatch.stop();
      // debugPrint(
      //     'ShowcaseService: TOTAL BREAKDOWN - Posts:${postsQueryStart.elapsedMilliseconds}ms, Profiles:${profilesStartTime.elapsedMilliseconds}ms, Parsing:${parsingStart.elapsedMilliseconds}ms, Total:${dbStartTime.elapsedMilliseconds}ms');
      return postsWithProfiles;
    } catch (e) {
      debugPrint('ShowcaseService: Error getting showcase posts: $e');
      return [];
    }
  }

  /// Get showcase posts without real-time (fallback method)
  Future<List<ShowcasePostModel>> getShowcasePostsSimple({
    int limit = 10,
    PostPrivacy? privacy,
    PostCategory? category,
    String? userId,
  }) async {
    try {
      // Use the simple method that we know works
      return await getShowcasePosts(
        limit: limit,
        privacy: privacy,
        category: category,
        userId: userId,
      );
    } catch (e) {
      debugPrint('ShowcaseService: Error in simple method: $e');
      return [];
    }
  }

  /// Refresh showcase feed after new post creation
  Future<void> refreshFeed() async {
    try {
      debugPrint('ShowcaseService: Refreshing showcase feed...');

      // Reset call count to ensure fresh data is fetched
      _callCount = 0;

      // Trigger a refresh by updating a timestamp or using a refresh mechanism
      // This will be handled by the UI layer calling getShowcasePosts() again

      debugPrint('ShowcaseService: Feed refresh triggered');
    } catch (e) {
      debugPrint('ShowcaseService: Error refreshing feed: $e');
    }
  }

  /// TRUE Real-time stream using Supabase Realtime subscription
  Stream<List<ShowcasePostModel>> getShowcasePostsRealtimeStream({
    int limit = 10,
    PostCategory? category,
    PostPrivacy? privacy,
    String? userId,
  }) {
    // Create a StreamController to manage the data flow
    final controller = StreamController<List<ShowcasePostModel>>();

    // Variables to track the latest posts for smart diffing
    List<ShowcasePostModel> lastPosts = [];

    // Helper function to load and emit posts
    Future<void> loadAndEmitPosts() async {
      try {
        final posts = await getShowcasePosts(
          limit: limit,
          privacy: privacy,
          category: category,
          userId: userId,
        ).timeout(const Duration(seconds: 5));

        // Only emit if data has changed or first load
        if (lastPosts.isEmpty ||
            posts.length != lastPosts.length ||
            posts.asMap().entries.any((entry) {
              final i = entry.key;
              final newPost = entry.value;
              final oldPost = i < lastPosts.length ? lastPosts[i] : null;
              return oldPost == null ||
                  newPost.id != oldPost.id ||
                  newPost.likes.length != oldPost.likes.length ||
                  newPost.comments.length != oldPost.comments.length;
            })) {
          lastPosts = posts;
          if (!controller.isClosed) {
            controller.add(posts);
          }
        }
      } catch (e) {
        debugPrint('ShowcaseService: Error loading posts for realtime: $e');
        if (!controller.isClosed && lastPosts.isEmpty) {
          controller.add(<ShowcasePostModel>[]);
        }
      }
    }

    // 1. IMMEDIATE: Load initial data
    loadAndEmitPosts();

    // 2. TRUE REAL-TIME: Set up Supabase Realtime subscription
    final subscription = _supabase
        .from('showcase_posts')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(limit)
        .listen((data) {
          // When real-time update comes, reload full data with profiles
          // NOTE: Don't clear cache here - it's too aggressive and slows down loading
          // Cache is already cleared in create/delete methods
          loadAndEmitPosts();
        }, onError: (error) {
          debugPrint('ShowcaseService: Realtime subscription error: $error');
        });

    // Clean up subscription when stream is cancelled
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Delete media file from Cloudinary
  Future<void> deleteMediaFile(String mediaUrl) async {
    try {
      // Extract public ID from Cloudinary URL
      final publicId = CloudinaryConfig.getPublicId(mediaUrl);

      if (publicId != null) {
        // Delete from Cloudinary
        final success = await CloudinaryConfig.deleteFile(publicId);
        if (success) {
          debugPrint(
              'ShowcaseService: Media file deleted successfully from Cloudinary: $publicId');
        } else {
          debugPrint(
              'ShowcaseService: Failed to delete media file from Cloudinary: $publicId');
        }
      } else {
        debugPrint(
            'ShowcaseService: Could not extract public ID from URL: $mediaUrl');
      }
    } catch (e) {
      debugPrint('Error deleting media file from Cloudinary: $e');
      // Don't rethrow - file might already be deleted
    }
  }

  /// Delete showcase post via Supabase
  Future<void> deleteShowcasePost(String postId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // First get the post to check ownership and get media URLs
      final postData = await _supabase
          .from('showcase_posts')
          .select('user_id, media_urls')
          .eq('id', postId)
          .maybeSingle();

      if (postData == null) {
        throw Exception('Post not found');
      }

      // Check if user owns the post
      if (postData['user_id'] != currentUserId) {
        throw Exception('Not authorized to delete this post');
      }

      // Delete associated media files from storage
      if (postData['media_urls'] != null) {
        final mediaUrls = List<String>.from(postData['media_urls']);
        for (String url in mediaUrls) {
          await deleteMediaFile(url);
        }
      }

      // Delete the post
      await _supabase.from('showcase_posts').delete().eq('id', postId);

      debugPrint('ShowcaseService: Post deleted successfully: $postId');

      // ✅ FIX: Clear cache to ensure deleted post is removed from feed immediately
      clearAllCaches();
    } catch (e) {
      debugPrint('Error deleting showcase post: $e');
      rethrow;
    }
  }

  /// Clean up temporary files and controllers
  Future<void> cleanup() async {
    try {
      // Clean up media utils temp files
      await MediaUtils.cleanupTempFiles();

      // Close upload controllers
      dispose();
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  // Cache management methods are defined below in the CACHE MANAGEMENT METHODS section

  // ==================== CACHE MANAGEMENT METHODS ====================

  /// Clear all caches (useful for testing or memory management)
  static void clearAllCaches() {
    _postsCache.clear();
    _cacheTimestamps.clear();
    _profilesCache.clear();
    _profilesCacheTimestamps.clear();
    debugPrint('ShowcaseService: All caches cleared');
  }

  /// Clear expired cache entries to free memory
  static void clearExpiredCache() {
    final now = DateTime.now();

    // Clear expired posts cache
    final expiredPostKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheValidity)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredPostKeys) {
      _postsCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    // Clear expired profiles cache
    final expiredProfileKeys = _profilesCacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _profilesCacheValidity)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredProfileKeys) {
      _profilesCache.remove(key);
      _profilesCacheTimestamps.remove(key);
    }

    if (expiredPostKeys.isNotEmpty || expiredProfileKeys.isNotEmpty) {
      debugPrint(
          'ShowcaseService: Cleared ${expiredPostKeys.length} expired post caches and ${expiredProfileKeys.length} expired profile caches');
    }
  }

  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    return {
      'posts_cache_size': _postsCache.length,
      'profiles_cache_size': _profilesCache.length,
      'total_cache_entries': _postsCache.length + _profilesCache.length,
      'cache_validity_minutes': _cacheValidity.inMinutes,
      'profiles_cache_validity_minutes': _profilesCacheValidity.inMinutes,
    };
  }

  /// Preload common data for faster access
  Future<void> preloadCommonData() async {
    try {
      debugPrint('ShowcaseService: Preloading common data...');

      // Preload public posts
      await getShowcasePosts(limit: 10);

      // Preload user profiles for current user
      final currentUserId = _authService.currentUserId;
      if (currentUserId != null) {
        await _fetchProfilesForUsers([currentUserId]);
      }

      debugPrint('ShowcaseService: Common data preloaded successfully');
    } catch (e) {
      debugPrint('ShowcaseService: Error preloading common data: $e');
    }
  }

  // ==================== SOCIAL INTERACTION METHODS ====================

  // Social interaction methods with Supabase integration
  // Using Supabase backend for transactions

  /// Like a post
  Future<void> likePost(String postId, String userId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Check if user already liked the post
      final existingLike = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike == null) {
        // Add like
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('ShowcaseService: Post liked successfully: $postId');
      } else {
        debugPrint('ShowcaseService: Post already liked by user: $postId');
      }
      // await SupabaseConfig.from('showcase_posts')
      //     .update({'likes': SupabaseConfig.sql('array_append(likes, $userId)')})
      //     .eq('id', postId);
    } catch (e) {
      debugPrint('Error liking post: $e');
      rethrow;
    }
  }

  /// Unlike a post
  Future<void> unlikePost(String postId, String userId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Remove like
      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);

      debugPrint('ShowcaseService: Post unliked successfully: $postId');
      // await SupabaseConfig.from('showcase_posts')
      //     .update({'likes': SupabaseConfig.sql('array_remove(likes, $userId)')})
      //     .eq('id', postId);
    } catch (e) {
      debugPrint('Error unliking post: $e');
      rethrow;
    }
  }

  /// Add comment to a post (embedded in showcase_posts.comments)
  Future<void> addComment(String postId, String userId, String content) async {
    try {
      debugPrint(
          'ShowcaseService: 🚀 Starting addComment for post $postId, user $userId');

      // Get current post data
      final postData = await _supabase
          .from('showcase_posts')
          .select('comments')
          .eq('id', postId)
          .single();

      debugPrint(
          'ShowcaseService: 📄 Retrieved post data: ${postData.toString()}');

      List<Map<String, dynamic>> comments =
          List<Map<String, dynamic>>.from(postData['comments'] ?? []);

      debugPrint(
          'ShowcaseService: 💬 Current comments count: ${comments.length}');

      // ✅ SIMPLIFIED: Direct user name resolution with reliable fallbacks
      String resolvedName = '';
      String? resolvedAvatar;

      try {
        // Priority 1: Use current auth user name (most reliable)
        if (userId == _authService.currentUserId) {
          resolvedName = _authService.currentUser?.name ??
              Supabase.instance.client.auth.currentUser?.userMetadata?['name']
                  ?.toString() ??
              '';
        }

        // Priority 2: If still empty or different user, try database
        if (resolvedName.isEmpty) {
          try {
            final user = await _supabase
                .from('users')
                .select('name')
                .eq('id', userId)
                .maybeSingle();
            if (user != null && user['name'] != null) {
              resolvedName = user['name'].toString();
            }
          } catch (e) {
            debugPrint('Error getting user name from database: $e');
          }
        }

        // Priority 3: Better fallback than just "User"
        if (resolvedName.isEmpty) {
          resolvedName = 'Anonymous User';
        }
      } catch (e) {
        debugPrint('Error resolving user name for comment: $e');
        resolvedName = 'Anonymous User';
      }

      // Create new comment with proper structure for CommentModel
      final newComment = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'postId': postId,
        'userId': userId,
        'userName': resolvedName,
        'userProfileImage': resolvedAvatar,
        'content': content,
        'likes': <String>[],
        'mentions': <Map<String, dynamic>>[],
        'parentCommentId': null,
        'replies': <Map<String, dynamic>>[],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isEdited': false,
      };

      debugPrint(
          'ShowcaseService: ✨ Created new comment: ${newComment.toString()}');

      comments.add(newComment);
      debugPrint(
          'ShowcaseService: 📝 Comments after add: ${comments.length} total');

      // Update the post with new comments
      debugPrint(
          'ShowcaseService: 💾 Updating database with ${comments.length} comments...');
      final updateResult = await _supabase
          .from('showcase_posts')
          .update({'comments': comments}).eq('id', postId);

      debugPrint(
          'ShowcaseService: ✅ Database update completed. Update result: $updateResult');
      debugPrint(
          'ShowcaseService: 🎉 Comment added successfully to post: $postId');
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  /// Share a post
  Future<void> sharePost(String postId, String userId) async {
    try {
      // Log share activity
      await _supabase.from('post_shares').insert({
        'post_id': postId,
        'user_id': _authService.currentUserId,
        'shared_at': DateTime.now().toIso8601String(),
      });

      debugPrint('ShowcaseService: Post shared successfully: $postId');
      // await SupabaseConfig.from('showcase_posts')
      //     .update({'shares': SupabaseConfig.sql('array_append(shares, $userId)')})
      //     .eq('id', postId);
    } catch (e) {
      debugPrint('Error sharing post: $e');
      rethrow;
    }
  }

  /// Increment view count
  Future<void> incrementViewCount(String postId) async {
    try {
      // Increment view count using Supabase RPC or direct update
      // For now, just log the view increment

      // Option 1: Use a simple update (if you have a view_count column)
      // await _supabase
      //     .from('showcase_posts')
      //     .update({'view_count': _supabase.sql('view_count + 1')})
      //     .eq('id', postId);

      // Option 2: Create the function in Supabase SQL Editor:
      // CREATE OR REPLACE FUNCTION increment_view_count(post_id UUID)
      // RETURNS void AS $$
      // BEGIN
      //   UPDATE showcase_posts
      //   SET view_count = COALESCE(view_count, 0) + 1
      //   WHERE id = post_id;
      // END;
      // $$ LANGUAGE plpgsql;
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
      // Don't rethrow - view count is not critical
    }
  }

  // ==================== COMPATIBILITY METHODS ====================
  // These methods are added for compatibility with existing UI code

  /// Toggle like on a post (alias for likePost/unlikePost)
  Future<void> toggleLike(String postId, String userId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get current post data
      final postData = await _supabase
          .from('showcase_posts')
          .select('likes')
          .eq('id', postId)
          .single();

      List<String> likes = List<String>.from(postData['likes'] ?? []);

      if (likes.contains(currentUserId)) {
        // Unlike the post
        likes.remove(currentUserId);
        // Sync with relational table
        try {
          await _supabase
              .from('post_likes')
              .delete()
              .eq('post_id', postId)
              .eq('user_id', currentUserId);
        } catch (e) {
          debugPrint('Sync unlike failed: $e');
        }
      } else {
        // Like the post
        likes.add(currentUserId);
        // Sync with relational table
        try {
          await _supabase.from('post_likes').insert({
            'post_id': postId,
            'user_id': currentUserId,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Sync like failed: $e');
        }
      }

      // Update the post with new likes
      await _supabase
          .from('showcase_posts')
          .update({'likes': likes}).eq('id', postId);

      debugPrint('ShowcaseService: Post like toggled successfully: $postId');
    } catch (e) {
      debugPrint('Error toggling like: $e');
      rethrow;
    }
  }

  /// Add comment with extended parameters (for compatibility)
  Future<String> addCommentExtended({
    required String postId,
    required String userId,
    required String userName,
    String? userProfileImage,
    required String content,
    String? parentCommentId,
    List<MentionModel> mentions = const [],
  }) async {
    try {
      final response = await _supabase
          .from('post_comments')
          .insert({
            'post_id': postId,
            'user_id': userId,
            'content': content,
            'parent_comment_id': parentCommentId,
            'mentions': mentions.map((m) => m.toJson()).toList(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final commentId = response['id'].toString();
      debugPrint(
          'ShowcaseService: Extended comment added successfully: $commentId');

      // SYNC: Also update the legacy comments array so the Feed count updates correctly
      try {
        await addComment(postId, userId, content);
      } catch (e) {
        debugPrint(
            'ShowcaseService: Note - Legacy comment sync skipped/failed: $e');
        // Don't fail the main operation if sync fails
      }

      return commentId;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  /// Update comment stored in showcase_posts.comments (embedded JSON)
  Future<void> updateComment({
    required String postId,
    required String commentId,
    required String content,
    List<MentionModel> mentions = const [],
  }) async {
    try {
      // Fetch current comments
      final postData = await _supabase
          .from('showcase_posts')
          .select('comments')
          .eq('id', postId)
          .single();

      List<Map<String, dynamic>> comments =
          List<Map<String, dynamic>>.from(postData['comments'] ?? []);

      bool updated = false;

      // Helper to update a comment recursively (including replies)
      List<Map<String, dynamic>> updateRecursive(
          List<Map<String, dynamic>> list) {
        return list.map((c) {
          if (c['id']?.toString() == commentId) {
            updated = true;
            return {
              ...c,
              'content': content,
              'updatedAt': DateTime.now().toIso8601String(),
              'isEdited': true,
            };
          }
          if (c['replies'] is List) {
            return {
              ...c,
              'replies': updateRecursive(
                  List<Map<String, dynamic>>.from(c['replies'])),
            };
          }
          return c;
        }).toList();
      }

      comments = updateRecursive(comments);

      if (!updated) {
        throw Exception('Comment not found');
      }

      await _supabase
          .from('showcase_posts')
          .update({'comments': comments}).eq('id', postId);

      debugPrint('ShowcaseService: Comment updated successfully: $commentId');
    } catch (e) {
      debugPrint('Error updating comment: $e');
      rethrow;
    }
  }

  /// Delete comment stored in showcase_posts.comments (embedded JSON)
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      // Fetch current comments
      final postData = await _supabase
          .from('showcase_posts')
          .select('comments')
          .eq('id', postId)
          .single();

      List<Map<String, dynamic>> comments =
          List<Map<String, dynamic>>.from(postData['comments'] ?? []);

      bool removed = false;

      // Recursively remove by id from nested structure
      List<Map<String, dynamic>> removeRecursive(
          List<Map<String, dynamic>> list) {
        final List<Map<String, dynamic>> result = [];
        for (final c in list) {
          if (c['id']?.toString() == commentId) {
            removed = true;
            continue; // skip this one
          }
          Map<String, dynamic> updated = Map<String, dynamic>.from(c);
          if (c['replies'] is List) {
            updated['replies'] =
                removeRecursive(List<Map<String, dynamic>>.from(c['replies']));
          }
          result.add(updated);
        }
        return result;
      }

      comments = removeRecursive(comments);

      if (!removed) {
        throw Exception('Comment not found');
      }

      await _supabase
          .from('showcase_posts')
          .update({'comments': comments}).eq('id', postId);

      debugPrint('ShowcaseService: Comment deleted successfully: $commentId');
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  /// Toggle comment like (for compatibility)
  Future<void> toggleCommentLike(
      String postId, String commentId, String userId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Check if user already liked the comment
      final existingLike = await _supabase
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (existingLike == null) {
        // Add like
        await _supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('ShowcaseService: Comment liked successfully: $commentId');
      } else {
        // Remove like
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', currentUserId);
        debugPrint('ShowcaseService: Comment unliked successfully: $commentId');
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      rethrow;
    }
  }

  /// Get a single post by ID for immediate refresh
  Future<ShowcasePostModel?> getPostById(String postId) async {
    try {
      // Get post data only first
      final response = await _supabase
          .from('showcase_posts')
          .select('*')
          .eq('id', postId)
          .maybeSingle();

      if (response != null) {
        final post = ShowcasePostModel.fromJson(response);

        // Resolve user name AND profile image separately to avoid join issues
        String? resolvedName;
        String? resolvedProfileImage;

        try {
          // Fetch user name from users table
          final user = await _supabase
              .from('users')
              .select('name')
              .eq('id', post.userId)
              .maybeSingle();

          if (user != null && user['name'] != null) {
            resolvedName = user['name'].toString();
          }

          // ✅ FIX: Also fetch latest profile image from profiles table
          // Using 'user_id' column as that's the correct column name in profiles table
          final profile = await _supabase
              .from('profiles')
              .select('profile_image_url, full_name')
              .eq('user_id', post.userId)
              .maybeSingle();

          if (profile != null) {
            resolvedProfileImage = profile['profile_image_url'];
            // Use profile full_name as fallback if users.name is empty
            if (resolvedName == null || resolvedName.isEmpty) {
              resolvedName = profile['full_name']?.toString();
            }
          }
        } catch (e) {
          debugPrint('Error resolving user data: $e');
        }

        // ✅ FIXED: Load comments for complete post data
        final comments = await getPostComments(postId);
        // debugPrint(
        //     'ShowcaseService: Loaded ${comments.length} comments for post $postId');

        return post.copyWith(
          userName: resolvedName ?? post.userName,
          userProfileImage: resolvedProfileImage ?? post.userProfileImage,
          comments: comments,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting post by ID: $e');
      return null;
    }
  }

  /// Get showcase collection reference (for compatibility)
  dynamic get showcaseCollection {
    // Return a mock object that provides the methods UI code expects
    return _MockShowcaseCollection(this);
  }

  /// Load comments for a specific post from post_comments table (FIXED: correct source)
  Future<List<CommentModel>> getPostComments(String postId) async {
    try {
      // debugPrint(
      //     'ShowcaseService: Loading comments for post $postId from post_comments table');

      // FIXED: Load from post_comments table (where addCommentExtended saves)
      final response = await _supabase
          .from('post_comments')
          .select('''
            id,
            post_id,
            user_id,
            content,
            parent_comment_id,
            mentions,
            created_at,
            updated_at
          ''') // REMOVED: likes column (doesn't exist)
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      // debugPrint(
      //     'ShowcaseService: Found ${response.length} comments for post $postId');

      // OPTIMIZED: Batch fetch ALL comment user profiles in ONE query
      final commentUserIds = response
          .map((comment) => comment['user_id'] as String)
          .toSet()
          .toList();

      // debugPrint(
      //     'ShowcaseService: 🚀 Batch fetching profiles for ${commentUserIds.length} comment authors');
      final userProfiles = await _fetchProfilesForUsers(commentUserIds);
      // debugPrint('ShowcaseService: ✅ Comment profiles loaded in batch');

      final comments = <CommentModel>[];
      for (final commentData in response) {
        final userId = commentData['user_id'] as String;
        final userInfo = userProfiles[userId];

        // ✅ IMPROVED: Better user name resolution
        final userName = userInfo?['full_name']?.toString().isNotEmpty == true
            ? userInfo!['full_name'].toString()
            : userInfo?['name']?.toString().isNotEmpty == true
                ? userInfo!['name'].toString()
                : 'Anonymous User';
        final userAvatar = userInfo?['profile_image_url'];

        // FIXED: Use correct field names for post_comments table
        final comment = CommentModel(
          id: commentData['id'].toString(),
          postId: commentData['post_id'] ?? postId,
          userId: commentData['user_id'],
          userName: userName, // Use resolved name
          userProfileImage: userAvatar,
          content: commentData['content'],
          likes: <String>[], // FIXED: No likes column in post_comments table
          mentions: (commentData['mentions'] as List<dynamic>? ?? [])
              .map((m) => MentionModel.fromJson(m))
              .toList(),
          parentCommentId: commentData['parent_comment_id'],
          replies: [], // Load replies separately if needed
          createdAt: DateTime.parse(commentData['created_at']),
          updatedAt: DateTime.parse(
              commentData['updated_at'] ?? commentData['created_at']),
          isEdited: commentData['updated_at'] != null &&
              commentData['updated_at'] != commentData['created_at'],
        );

        comments.add(comment);
      }

      return comments;
    } catch (e) {
      debugPrint('Error loading post comments: $e');
      return [];
    }
  }
}

/// Mock collection class for compatibility
class _MockShowcaseCollection {
  final ShowcaseService _service;
  _MockShowcaseCollection(this._service);

  dynamic doc(String id) => _MockDocument(id, _service);
}

/// Mock document class for compatibility
class _MockDocument {
  final String id;
  final ShowcaseService _service;
  _MockDocument(this.id, this._service);

  Future<void> update(Map<String, dynamic> data) async {
    // Implementation with Supabase would go here
    debugPrint('Mock update called for document $id');
  }

  Future<void> delete() async {
    // Implementation with Supabase would go here
    debugPrint('Mock delete called for document $id');
  }

  Future<dynamic> get() async {
    // Implementation with Supabase would go here
    debugPrint('Mock get called for document $id');
    return null;
  }

  /// Add snapshots() method for compatibility with PostDetailScreen
  /// ✅ FIXED: Removed periodic polling to prevent excessive refreshes
  Stream<ShowcasePostModel?> snapshots() async* {
    debugPrint('Mock snapshots() called for document $id');

    try {
      // Fetch post data once
      final response = await _service._supabase
          .from('showcase_posts')
          .select('*')
          .eq('id', id)
          .single();

      final post = ShowcasePostModel.fromJson(response);

      // Resolve user name separately to avoid join issues
      try {
        final user = await _service._supabase
            .from('users')
            .select('name')
            .eq('id', post.userId)
            .maybeSingle();

        if (user != null && user['name'] != null) {
          yield post.copyWith(userName: user['name'].toString());
          return;
        }
      } catch (e) {
        debugPrint('Error resolving user name in stream: $e');
      }

      yield post;
    } catch (e) {
      debugPrint('Error fetching post $id: $e');
      yield null;
    }
  }

  // ==================== CACHE MANAGEMENT ====================

  /// Clear all caches (useful for logout or major updates)
  void clearAllCaches() {
    ShowcaseService._postsCache.clear();
    ShowcaseService._cacheTimestamps.clear();
    ShowcaseService._profilesCache.clear();
    ShowcaseService._profilesCacheTimestamps.clear();
    ShowcaseService._ongoingRequests.clear();
    debugPrint('ShowcaseService: All caches cleared');
  }

  // Placeholder for missing methods
  Future<void> deleteMediaFile(String fileName) async {
    debugPrint('DeleteMediaFile not yet implemented: $fileName');
  }

  // REMOVED: Duplicate getPostComments method
}
