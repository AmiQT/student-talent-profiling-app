import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';

/// Utility class for media handling and validation
class MediaUtils {
  // File size limits (in bytes)
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB

  // Supported formats
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp'
  ];
  static const List<String> supportedVideoFormats = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm'
  ];

  // Image compression settings
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  static const int imageQuality = 85;

  /// Validate if file is a supported image format
  static bool isValidImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return supportedImageFormats.contains(extension);
  }

  /// Validate if file is a supported video format
  static bool isValidVideoFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return supportedVideoFormats.contains(extension);
  }

  /// Check if image file size is within limits
  static bool isValidImageSize(File file) {
    return file.lengthSync() <= maxImageSize;
  }

  /// Check if video file size is within limits
  static bool isValidVideoSize(File file) {
    return file.lengthSync() <= maxVideoSize;
  }

  /// Compress image file
  static Future<File?> compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Resize if necessary
      img.Image resized = image;
      if (image.width > maxImageWidth || image.height > maxImageHeight) {
        resized = img.copyResize(
          image,
          width: image.width > maxImageWidth ? maxImageWidth : null,
          height: image.height > maxImageHeight ? maxImageHeight : null,
        );
      }

      // Compress
      final compressedBytes = img.encodeJpg(resized, quality: imageQuality);

      // Create new file
      final compressedFile = File('${file.path}_compressed.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// Compress video file
  static Future<File?> compressVideo(File file) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      return info?.file;
    } catch (e) {
      debugPrint('Error compressing video: $e');
      return null;
    }
  }

  /// Generate video thumbnail
  static Future<File?> generateVideoThumbnail(File videoFile) async {
    try {
      final thumbnail = await VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: 50,
        position: -1, // Get thumbnail from middle of video
      );

      return thumbnail;
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      return null;
    }
  }

  /// Get video duration
  static Future<int?> getVideoDuration(File videoFile) async {
    try {
      final info = await VideoCompress.getMediaInfo(videoFile.path);
      return info.duration?.toInt();
    } catch (e) {
      debugPrint('Error getting video duration: $e');
      return null;
    }
  }

  /// Get image dimensions
  static Future<Map<String, int>?> getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return null;
    }
  }

  /// Calculate aspect ratio
  static double calculateAspectRatio(int width, int height) {
    return width / height;
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Validate media file
  static Future<MediaValidationResult> validateMediaFile(File file) async {
    final fileName = file.path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();
    final fileSize = file.lengthSync();

    // Check if it's an image
    if (supportedImageFormats.contains(extension)) {
      if (!isValidImageSize(file)) {
        return MediaValidationResult(
          isValid: false,
          error: 'Image size exceeds ${formatFileSize(maxImageSize)} limit',
        );
      }

      final dimensions = await getImageDimensions(file);
      return MediaValidationResult(
        isValid: true,
        mediaType: 'image',
        fileSize: fileSize,
        width: dimensions?['width'],
        height: dimensions?['height'],
      );
    }

    // Check if it's a video
    if (supportedVideoFormats.contains(extension)) {
      if (!isValidVideoSize(file)) {
        return MediaValidationResult(
          isValid: false,
          error: 'Video size exceeds ${formatFileSize(maxVideoSize)} limit',
        );
      }

      final duration = await getVideoDuration(file);
      return MediaValidationResult(
        isValid: true,
        mediaType: 'video',
        fileSize: fileSize,
        duration: duration,
      );
    }

    return MediaValidationResult(
      isValid: false,
      error: 'Unsupported file format: $extension',
    );
  }

  /// Clean up temporary files
  static Future<void> cleanupTempFiles() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }
}

/// Result of media validation
class MediaValidationResult {
  final bool isValid;
  final String? error;
  final String? mediaType;
  final int? fileSize;
  final int? width;
  final int? height;
  final int? duration;

  MediaValidationResult({
    required this.isValid,
    this.error,
    this.mediaType,
    this.fileSize,
    this.width,
    this.height,
    this.duration,
  });

  double? get aspectRatio {
    if (width != null && height != null) {
      return MediaUtils.calculateAspectRatio(width!, height!);
    }
    return null;
  }

  String? get formattedFileSize {
    if (fileSize != null) {
      return MediaUtils.formatFileSize(fileSize!);
    }
    return null;
  }
}
