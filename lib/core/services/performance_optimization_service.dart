import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';

/// Performance optimization service for mobile treasure hunting app
/// Focuses on battery life, data usage, and response time optimization
class PerformanceOptimizationService {
  static final PerformanceOptimizationService _instance = PerformanceOptimizationService._internal();
  factory PerformanceOptimizationService() => _instance;
  PerformanceOptimizationService._internal();

  final BFFMappingService _bffService = BFFMappingService.instance;
  final OfflineLandRightsService _offlineService = OfflineLandRightsService();

  // Performance configuration
  static const int _maxConcurrentRequests = 3;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _cacheValidityPeriod = Duration(hours: 4);
  // Reserved for future preloading feature
  // ignore: unused_field
  static const double _preloadRadiusKm = 2.0; // Preload 2km ahead
  static const int _maxCachedProperties = 1000; // Limit memory usage
  
  // Internal state
  final Map<String, DateTime> _requestCache = {};
  final Map<String, List<ComprehensiveLandOwnership>> _memoryCache = {};
  final List<Timer> _activeTimers = [];
  int _activeRequests = 0;
  
  /// Performance metrics
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _networkRequests = 0;
  Duration _totalResponseTime = Duration.zero;

  /// Initialize the performance optimization service
  Future<void> initialize() async {
    await _offlineService.initialize();
    _startPerformanceMonitoring();
    debugPrint('Performance optimization service initialized');
  }

  /// Get optimized land rights data with intelligent caching
  Future<List<ComprehensiveLandOwnership>> getOptimizedLandRights({
    required double latitude,
    required double longitude,
    required double radiusKm,
    bool forceRefresh = false,
  }) async {
    final startTime = DateTime.now();
    _totalRequests++;
    
    try {
      final bounds = _calculateBounds(latitude, longitude, radiusKm);
      final cacheKey = _generateCacheKey(bounds.northBound, bounds.southBound, bounds.eastBound, bounds.westBound);
      
      // Check memory cache first
      if (!forceRefresh && _isMemoryCacheValid(cacheKey)) {
        _cacheHits++;
        final cached = _memoryCache[cacheKey]!;
        debugPrint('Performance Service: Memory cache hit for $cacheKey (${cached.length} properties)');
        return cached;
      }

      // Check offline cache
      final offlineResults = await _offlineService.queryOfflineProperties(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );

      if (offlineResults.isNotEmpty && !forceRefresh) {
        _cacheHits++;
        _updateMemoryCache(cacheKey, offlineResults);
        debugPrint('Performance Service: Offline cache hit (${offlineResults.length} properties)');
        return offlineResults;
      }

      // Rate limit network requests
      if (_activeRequests >= _maxConcurrentRequests) {
        debugPrint('Performance Service: Rate limiting - using cached data');
        return offlineResults; // Return cached data if available
      }

      // Fetch from network with timeout
      _activeRequests++;
      _networkRequests++;
      
      debugPrint('Performance Service: Fetching from network (active requests: $_activeRequests)');
      
      final networkResults = await _bffService.getComprehensiveLandRightsData(
        northBound: bounds.northBound,
        southBound: bounds.southBound,
        eastBound: bounds.eastBound,
        westBound: bounds.westBound,
        limit: 100,
      ).timeout(_requestTimeout);

      // Cache results
      _updateMemoryCache(cacheKey, networkResults);
      await _offlineService.cacheProperties(networkResults);
      
      debugPrint('Performance Service: Network request completed (${networkResults.length} properties)');
      return networkResults;

    } catch (e) {
      debugPrint('Performance Service: Network request failed: $e');
      
      // Fallback to offline data
      final fallbackResults = await _offlineService.queryOfflineProperties(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm * 2, // Expand radius for fallback
      );
      
      debugPrint('Performance Service: Using fallback data (${fallbackResults.length} properties)');
      return fallbackResults;
      
    } finally {
      _activeRequests--;
      final responseTime = DateTime.now().difference(startTime);
      _totalResponseTime += responseTime;
      debugPrint('Performance Service: Request completed in ${responseTime.inMilliseconds}ms');
    }
  }

  /// Preload land rights data ahead of user movement
  Future<void> preloadDataAlongTrail({
    required List<Position> trailPoints,
    double radiusKm = 1.0,
  }) async {
    if (trailPoints.isEmpty) return;
    
    debugPrint('Performance Service: Preloading data for ${trailPoints.length} trail points');
    
    // Process points in batches to avoid overwhelming the system
    const batchSize = 5;
    for (int i = 0; i < trailPoints.length; i += batchSize) {
      final batch = trailPoints.skip(i).take(batchSize).toList();
      
      final futures = batch.map((point) async {
        try {
          await getOptimizedLandRights(
            latitude: point.latitude,
            longitude: point.longitude,
            radiusKm: radiusKm,
          );
        } catch (e) {
          debugPrint('Performance Service: Preload failed for point ${point.latitude}, ${point.longitude}: $e');
        }
      });
      
      await Future.wait(futures);
      
      // Small delay between batches to prevent overwhelming
      if (i + batchSize < trailPoints.length) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    
    debugPrint('Performance Service: Trail preloading completed');
  }

  /// Smart preloading based on current movement direction
  Future<void> predictivePreload({
    required Position currentPosition,
    required Position previousPosition,
    double preloadDistanceKm = 2.0,
  }) async {
    // Calculate movement vector
    final deltaLat = currentPosition.latitude - previousPosition.latitude;
    final deltaLon = currentPosition.longitude - previousPosition.longitude;
    
    if (deltaLat.abs() < 0.0001 && deltaLon.abs() < 0.0001) {
      // Not moving significantly, no preload needed
      return;
    }
    
    // Predict future position based on movement
    final speed = Geolocator.distanceBetween(
      previousPosition.latitude,
      previousPosition.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    ) / 1000; // km
    
    if (speed < 0.1) return; // Too slow to predict
    
    // Predict position 5 minutes ahead
    const predictionMinutes = 5.0;
    final predictedLat = currentPosition.latitude + (deltaLat * predictionMinutes);
    final predictedLon = currentPosition.longitude + (deltaLon * predictionMinutes);
    
    debugPrint('Performance Service: Predictive preload for ($predictedLat, $predictedLon)');
    
    // Preload data at predicted location
    await getOptimizedLandRights(
      latitude: predictedLat,
      longitude: predictedLon,
      radiusKm: preloadDistanceKm,
    );
  }

  /// Optimize memory usage by cleaning old cache entries
  Future<void> optimizeMemoryUsage() async {
    final now = DateTime.now();
    
    // Remove expired entries
    _requestCache.removeWhere((key, timestamp) {
      return now.difference(timestamp) > _cacheValidityPeriod;
    });
    
    // Limit memory cache size
    if (_memoryCache.length > _maxCachedProperties) {
      final sortedKeys = _memoryCache.keys.toList()
        ..sort((a, b) => (_requestCache[b] ?? DateTime(0))
            .compareTo(_requestCache[a] ?? DateTime(0)));
      
      // Keep most recently used entries
      final keysToRemove = sortedKeys.skip(_maxCachedProperties ~/ 2);
      keysToRemove.forEach(_memoryCache.remove);
      
      debugPrint('Performance Service: Memory cache optimized (${_memoryCache.length} entries)');
    }
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final averageResponseTime = _totalRequests > 0 
        ? _totalResponseTime.inMilliseconds / _totalRequests 
        : 0.0;
    
    final cacheHitRate = _totalRequests > 0 
        ? (_cacheHits / _totalRequests * 100).toStringAsFixed(1)
        : '0.0';
    
    return {
      'total_requests': _totalRequests,
      'cache_hits': _cacheHits,
      'network_requests': _networkRequests,
      'cache_hit_rate': '$cacheHitRate%',
      'average_response_time_ms': averageResponseTime.toStringAsFixed(1),
      'active_requests': _activeRequests,
      'memory_cache_entries': _memoryCache.length,
      'memory_cache_size': _estimateMemoryCacheSize(),
    };
  }

  /// Reset performance metrics
  void resetMetrics() {
    _totalRequests = 0;
    _cacheHits = 0;
    _networkRequests = 0;
    _totalResponseTime = Duration.zero;
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
    _requestCache.clear();
    _memoryCache.clear();
  }

  // Private helper methods

  void _startPerformanceMonitoring() {
    // Periodic memory optimization
    final timer = Timer.periodic(const Duration(minutes: 5), (_) {
      optimizeMemoryUsage();
    });
    _activeTimers.add(timer);
  }

  _Bounds _calculateBounds(double lat, double lon, double radiusKm) {
    final radiusDegrees = radiusKm / 111.0; // Rough conversion
    return _Bounds(
      northBound: lat + radiusDegrees,
      southBound: lat - radiusDegrees,
      eastBound: lon + radiusDegrees,
      westBound: lon - radiusDegrees,
    );
  }

  String _generateCacheKey(double north, double south, double east, double west) {
    // Round to reduce cache fragmentation
    final n = (north * 1000).round();
    final s = (south * 1000).round();
    final e = (east * 1000).round();
    final w = (west * 1000).round();
    return '$n,$s,$e,$w';
  }

  bool _isMemoryCacheValid(String cacheKey) {
    if (!_memoryCache.containsKey(cacheKey)) return false;
    
    final timestamp = _requestCache[cacheKey];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheValidityPeriod;
  }

  void _updateMemoryCache(String cacheKey, List<ComprehensiveLandOwnership> data) {
    _memoryCache[cacheKey] = data;
    _requestCache[cacheKey] = DateTime.now();
  }

  String _estimateMemoryCacheSize() {
    int totalSize = 0;
    for (final entry in _memoryCache.values) {
      totalSize += entry.length * 2048; // Estimate 2KB per property
    }
    
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Bounds {
  final double northBound;
  final double southBound;
  final double eastBound;
  final double westBound;

  _Bounds({
    required this.northBound,
    required this.southBound,
    required this.eastBound,
    required this.westBound,
  });
}