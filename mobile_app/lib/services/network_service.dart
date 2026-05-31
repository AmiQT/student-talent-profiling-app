import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Network state
  bool _isConnected = true;
  ConnectivityResult _connectionType = ConnectivityResult.wifi;

  // Getters
  bool get isConnected => _isConnected;
  bool get isOnWifi => _connectionType == ConnectivityResult.wifi;
  bool get isOnMobile => _connectionType == ConnectivityResult.mobile;
  bool get isOnSlowConnection => _connectionType == ConnectivityResult.mobile;

  // Initialize network monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    _connectionType = await _connectivity.checkConnectivity();
    _isConnected = _connectionType != ConnectivityResult.none;

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _connectionType = result;
        _isConnected = result != ConnectivityResult.none;
        debugPrint('📶 Network changed: $result');

        // Notify app about network changes
        _notifyNetworkChange(result);
      },
    );

    debugPrint('📶 Network initialized: $_connectionType');
  }

  void _notifyNetworkChange(ConnectivityResult result) {
    // You can implement app-wide network change notifications here
    if (result == ConnectivityResult.none) {
      debugPrint('❌ Network disconnected');
    } else if (result == ConnectivityResult.mobile) {
      debugPrint('📱 Switched to mobile data');
    } else if (result == ConnectivityResult.wifi) {
      debugPrint('📶 Switched to WiFi');
    }
  }

  // Dispose
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  // Check if we should use data-saving mode
  bool shouldUseDataSavingMode() {
    return isOnMobile; // Enable data saving on mobile connections
  }

  // Get appropriate timeout based on connection
  Duration getTimeoutDuration() {
    if (isOnMobile) {
      return const Duration(seconds: 10); // Optimized mobile timeout
    }
    return const Duration(seconds: 8); // Faster timeout for WiFi
  }

  // Get appropriate image quality based on connection
  String getImageQuality() {
    if (isOnMobile) {
      return 'medium'; // Lower quality for mobile data
    }
    return 'high'; // High quality for WiFi
  }

  // Check if large downloads should be allowed
  bool shouldAllowLargeDownloads() {
    return isOnWifi; // Only allow large downloads on WiFi
  }
}

// HTTP Client with mobile data optimizations
class OptimizedHttpClient {
  static final OptimizedHttpClient _instance = OptimizedHttpClient._internal();
  factory OptimizedHttpClient() => _instance;
  OptimizedHttpClient._internal();

  final NetworkService _networkService = NetworkService();
  late http.Client _client;

  void initialize() {
    _client = http.Client();
  }

  // Optimized GET request
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool enableCompression = true,
  }) async {
    final optimizedHeaders = _getOptimizedHeaders(headers, enableCompression);

    try {
      final response = await _client
          .get(url, headers: optimizedHeaders)
          .timeout(_networkService.getTimeoutDuration());

      debugPrint(
          '📡 GET ${url.path}: ${response.statusCode} (${response.contentLength ?? 0} bytes)');
      return response;
    } catch (e) {
      debugPrint('❌ GET ${url.path} failed: $e');
      rethrow;
    }
  }

  // Optimized POST request
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool enableCompression = true,
  }) async {
    final optimizedHeaders = _getOptimizedHeaders(headers, enableCompression);

    try {
      final response = await _client
          .post(url, headers: optimizedHeaders, body: body)
          .timeout(_networkService.getTimeoutDuration());

      debugPrint('📡 POST ${url.path}: ${response.statusCode}');
      return response;
    } catch (e) {
      debugPrint('❌ POST ${url.path} failed: $e');
      rethrow;
    }
  }

  // Optimized PUT request
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool enableCompression = true,
  }) async {
    final optimizedHeaders = _getOptimizedHeaders(headers, enableCompression);

    try {
      final response = await _client
          .put(url, headers: optimizedHeaders, body: body)
          .timeout(_networkService.getTimeoutDuration());

      debugPrint('📡 PUT ${url.path}: ${response.statusCode}');
      return response;
    } catch (e) {
      debugPrint('❌ PUT ${url.path} failed: $e');
      rethrow;
    }
  }

  // Get optimized headers for mobile data
  Map<String, String> _getOptimizedHeaders(
    Map<String, String>? headers,
    bool enableCompression,
  ) {
    final optimizedHeaders = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'StudentTalentApp/1.0',
    };

    // Add compression headers for mobile data
    if (enableCompression && _networkService.isOnMobile) {
      optimizedHeaders['Accept-Encoding'] = 'gzip, deflate';
      optimizedHeaders['Cache-Control'] = 'max-age=300'; // 5 minutes cache
    }

    // Add custom headers
    if (headers != null) {
      optimizedHeaders.addAll(headers);
    }

    return optimizedHeaders;
  }

  void dispose() {
    _client.close();
  }
}

// Data usage tracker
class DataUsageTracker {
  static final DataUsageTracker _instance = DataUsageTracker._internal();
  factory DataUsageTracker() => _instance;
  DataUsageTracker._internal();

  int _sessionBytesDownloaded = 0;
  int _sessionBytesUploaded = 0;

  // Track download
  void trackDownload(int bytes) {
    _sessionBytesDownloaded += bytes;
    debugPrint(
        '📊 Downloaded: ${_formatBytes(bytes)} (Session: ${_formatBytes(_sessionBytesDownloaded)})');
  }

  // Track upload
  void trackUpload(int bytes) {
    _sessionBytesUploaded += bytes;
    debugPrint(
        '📊 Uploaded: ${_formatBytes(bytes)} (Session: ${_formatBytes(_sessionBytesUploaded)})');
  }

  // Get session usage
  Map<String, String> getSessionUsage() {
    return {
      'downloaded': _formatBytes(_sessionBytesDownloaded),
      'uploaded': _formatBytes(_sessionBytesUploaded),
      'total': _formatBytes(_sessionBytesDownloaded + _sessionBytesUploaded),
    };
  }

  // Reset session counters
  void resetSession() {
    _sessionBytesDownloaded = 0;
    _sessionBytesUploaded = 0;
  }

  // Format bytes to human readable
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  // Check if data usage is high
  bool isHighDataUsage() {
    const highUsageThreshold = 50 * 1024 * 1024; // 50MB per session
    return (_sessionBytesDownloaded + _sessionBytesUploaded) >
        highUsageThreshold;
  }
}
