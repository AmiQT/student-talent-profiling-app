import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/showcase_models.dart';
import '../models/post_creation_models.dart';
import '../utils/media_utils.dart';
import '../config/cloudinary_config.dart';
import 'showcase_service.dart';

/// Comprehensive media upload manager for handling complex upload workflows
class MediaUploadManager {
  final ShowcaseService _showcaseService = ShowcaseService();

  // Upload state tracking
  final Map<String, PostCreationState> _uploadStates = {};
  final Map<String, StreamController<PostCreationState>> _stateControllers = {};

  // Singleton pattern
  static final MediaUploadManager _instance = MediaUploadManager._internal();
  factory MediaUploadManager() => _instance;
  MediaUploadManager._internal();

  /// Get upload state stream for a specific upload session
  Stream<PostCreationState> getUploadStateStream(String sessionId) {
    if (!_stateControllers.containsKey(sessionId)) {
      _stateControllers[sessionId] =
          StreamController<PostCreationState>.broadcast();
    }
    return _stateControllers[sessionId]!.stream;
  }

  /// Start a new upload session
  String startUploadSession() {
    final sessionId = 'upload_${DateTime.now().millisecondsSinceEpoch}';
    _uploadStates[sessionId] = PostCreationState();
    return sessionId;
  }

  /// Update upload state and notify listeners
  void _updateUploadState(String sessionId, PostCreationState state) {
    _uploadStates[sessionId] = state;
    final controller = _stateControllers[sessionId];
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  /// Validate and prepare media files for upload
  Future<MediaValidationResult> validateMediaFiles(List<File> files) async {
    try {
      if (files.isEmpty) {
        return MediaValidationResult(
            isValid: false, error: 'No files selected');
      }

      if (files.length > 10) {
        return MediaValidationResult(
            isValid: false, error: 'Maximum 10 files allowed per post');
      }

      int totalSize = 0;
      for (final file in files) {
        final validation = await MediaUtils.validateMediaFile(file);
        if (!validation.isValid) {
          return validation;
        }
        totalSize += validation.fileSize ?? 0;
      }

      // Check total size limit (500MB)
      const maxTotalSize = 500 * 1024 * 1024;
      if (totalSize > maxTotalSize) {
        return MediaValidationResult(
          isValid: false,
          error: 'Total file size exceeds 500MB limit',
        );
      }

      return MediaValidationResult(isValid: true);
    } catch (e) {
      return MediaValidationResult(
        isValid: false,
        error: 'Error validating files: $e',
      );
    }
  }

  /// Upload media files with comprehensive progress tracking
  Future<PostCreationResult> uploadPost({
    required String sessionId,
    required String userId,
    required String userName,
    String? userProfileImage,
    String? userRole,
    String? userDepartment,
    String? userHeadline,
    required String content,
    List<File> mediaFiles = const [],
    PostCategory category = PostCategory.general,
    PostPrivacy privacy = PostPrivacy.public,
    List<String> tags = const [],
    List<MentionModel> mentions = const [],
    String? location,
  }) async {
    try {
      // Initialize upload state
      _updateUploadState(
          sessionId,
          PostCreationState(
            content: content,
            selectedMedia: mediaFiles,
            tags: tags,
            category: category,
            privacy: privacy,
            location: location,
            mentionedUsers: mentions.map((m) => m.userId).toList(),
            isUploading: true,
            uploadProgress: 0.0,
          ));

      // Validate media files
      if (mediaFiles.isNotEmpty) {
        final validation = await validateMediaFiles(mediaFiles);
        if (!validation.isValid) {
          _updateUploadState(
              sessionId,
              _uploadStates[sessionId]!.copyWith(
                isUploading: false,
                error: validation.error,
              ));
          return PostCreationResult.failure(error: validation.error!);
        }
      }

      // Create post with progress tracking
      final result = await _showcaseService.createShowcasePost(
        content: content,
        type: PostType.mixed, // Default to mixed type
        category: category,
        privacy: privacy,
        mediaFiles: mediaFiles,
        tags: tags,
        mentions: mentions,
        location: location,
      );

      // Update final state
      if (result.success) {
        _updateUploadState(
            sessionId,
            _uploadStates[sessionId]!.copyWith(
              isUploading: false,
              uploadProgress: 1.0,
              error: null,
            ));
      } else {
        _updateUploadState(
            sessionId,
            _uploadStates[sessionId]!.copyWith(
              isUploading: false,
              error: result.error,
            ));
      }

      return result;
    } catch (e) {
      _updateUploadState(
          sessionId,
          _uploadStates[sessionId]!.copyWith(
            isUploading: false,
            error: e.toString(),
          ));
      return PostCreationResult.failure(error: e.toString());
    }
  }

  /// Upload media files with XFile support (for web/mobile compatibility)
  /// This method converts XFile to bytes and uploads directly to Cloudinary
  Future<PostCreationResult> uploadPostWithXFiles({
    required String sessionId,
    required String userId,
    required String userName,
    String? userProfileImage,
    String? userRole,
    String? userDepartment,
    String? userHeadline,
    required String content,
    List<XFile> mediaFiles = const [],
    PostCategory category = PostCategory.general,
    PostPrivacy privacy = PostPrivacy.public,
    List<String> tags = const [],
    List<MentionModel> mentions = const [],
    String? location,
  }) async {
    try {
      // Initialize upload state (with empty File list for state tracking)
      _updateUploadState(
          sessionId,
          PostCreationState(
            content: content,
            selectedMedia: const [], // Empty - we're using XFile instead
            tags: tags,
            category: category,
            privacy: privacy,
            location: location,
            mentionedUsers: mentions.map((m) => m.userId).toList(),
            isUploading: true,
            uploadProgress: 0.0,
          ));

      // Upload media files using bytes-based approach
      List<String> uploadedUrls = [];
      List<String> mediaTypes = [];

      if (mediaFiles.isNotEmpty) {
        debugPrint(
            'MediaUploadManager: Uploading ${mediaFiles.length} XFiles...');

        for (int i = 0; i < mediaFiles.length; i++) {
          final xFile = mediaFiles[i];
          final bytes = await xFile.readAsBytes();
          final filename = xFile.name;
          final extension = filename.split('.').last.toLowerCase();

          String uploadedUrl;
          String mediaType;

          // Determine if image or video based on extension
          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
            uploadedUrl = await _uploadImageBytes(
              bytes: bytes,
              filename: filename,
              userId: userId,
            );
            mediaType = 'image';
          } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
            uploadedUrl = await _uploadVideoBytes(
              bytes: bytes,
              filename: filename,
              userId: userId,
            );
            mediaType = 'video';
          } else {
            // Default to image upload
            uploadedUrl = await _uploadImageBytes(
              bytes: bytes,
              filename: filename,
              userId: userId,
            );
            mediaType = 'image';
          }

          uploadedUrls.add(uploadedUrl);
          mediaTypes.add(mediaType);

          // Update progress
          final progress = (i + 1) / mediaFiles.length;
          _updateUploadState(
              sessionId,
              _uploadStates[sessionId]!.copyWith(
                uploadProgress: progress * 0.8, // Reserve 20% for post creation
              ));
        }
      }

      // Create post with uploaded media URLs
      final result = await _showcaseService.createShowcasePostWithUrls(
        content: content,
        type: PostType.mixed,
        category: category,
        privacy: privacy,
        mediaUrls: uploadedUrls,
        mediaTypes: mediaTypes,
        tags: tags,
        mentions: mentions,
        location: location,
      );

      // Update final state
      if (result.success) {
        _updateUploadState(
            sessionId,
            _uploadStates[sessionId]!.copyWith(
              isUploading: false,
              uploadProgress: 1.0,
              error: null,
            ));
      } else {
        _updateUploadState(
            sessionId,
            _uploadStates[sessionId]!.copyWith(
              isUploading: false,
              error: result.error,
            ));
      }

      return result;
    } catch (e) {
      _updateUploadState(
          sessionId,
          _uploadStates[sessionId]!.copyWith(
            isUploading: false,
            error: e.toString(),
          ));
      return PostCreationResult.failure(error: e.toString());
    }
  }

  /// Upload image bytes to Cloudinary
  Future<String> _uploadImageBytes({
    required Uint8List bytes,
    required String filename,
    required String userId,
  }) async {
    final uri =
        Uri.parse(CloudinaryConfig.imageUploadUrl);
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = 'STAP-media';
    request.fields['folder'] = 'showcase_media/$userId';
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final jsonResponse = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonResponse['secure_url'] as String;
    } else {
      throw Exception(
          'Upload failed: ${jsonResponse['error'] ?? 'Unknown error'}');
    }
  }

  /// Upload video bytes to Cloudinary
  Future<String> _uploadVideoBytes({
    required Uint8List bytes,
    required String filename,
    required String userId,
  }) async {
    final uri =
        Uri.parse(CloudinaryConfig.videoUploadUrl);
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = 'STAP-media';
    request.fields['folder'] = 'showcase_media/$userId';
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final jsonResponse = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonResponse['secure_url'] as String;
    } else {
      throw Exception(
          'Upload failed: ${jsonResponse['error'] ?? 'Unknown error'}');
    }
  }

  /// Prepare media files for upload (compress, validate, generate thumbnails)
  Future<List<File>> prepareMediaFiles(List<File> files) async {
    final List<File> preparedFiles = [];

    try {
      for (final file in files) {
        final validation = await MediaUtils.validateMediaFile(file);
        if (!validation.isValid) {
          throw Exception('Invalid file: ${validation.error}');
        }

        File? preparedFile;

        if (validation.mediaType == 'image') {
          // Compress image
          preparedFile = await MediaUtils.compressImage(file);
          preparedFile ??= file; // Use original if compression fails
        } else if (validation.mediaType == 'video') {
          // Compress video
          preparedFile = await MediaUtils.compressVideo(file);
          preparedFile ??= file; // Use original if compression fails
        } else {
          preparedFile = file;
        }

        preparedFiles.add(preparedFile);
      }

      return preparedFiles;
    } catch (e) {
      debugPrint('Error preparing media files: $e');
      rethrow;
    }
  }

  /// Get upload statistics
  Map<String, dynamic> getUploadStats(String sessionId) {
    final state = _uploadStates[sessionId];
    if (state == null) return {};

    return {
      'totalFiles': state.selectedMedia.length,
      'uploadProgress': state.uploadProgress,
      'isUploading': state.isUploading,
      'hasError': state.hasError,
      'canPost': state.canPost,
      'postType': state.postType.toString().split('.').last,
    };
  }

  /// Cancel upload session
  void cancelUploadSession(String sessionId) {
    _updateUploadState(
        sessionId,
        _uploadStates[sessionId]!.copyWith(
          isUploading: false,
          error: 'Upload cancelled by user',
        ));
  }

  /// Clean up upload session
  void cleanupSession(String sessionId) {
    _uploadStates.remove(sessionId);
    final controller = _stateControllers[sessionId];
    if (controller != null) {
      controller.close();
      _stateControllers.remove(sessionId);
    }
  }

  /// Clean up all sessions
  void cleanupAllSessions() {
    _uploadStates.clear();
    for (final controller in _stateControllers.values) {
      controller.close();
    }
    _stateControllers.clear();
  }

  /// Get current upload state
  PostCreationState? getUploadState(String sessionId) {
    return _uploadStates[sessionId];
  }

  /// Check if session is uploading
  bool isSessionUploading(String sessionId) {
    final state = _uploadStates[sessionId];
    return state?.isUploading ?? false;
  }

  /// Get all active sessions
  List<String> getActiveSessions() {
    return _uploadStates.keys.toList();
  }

  /// Dispose resources
  void dispose() {
    cleanupAllSessions();
    _showcaseService.dispose();
  }
}
