import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FirebaseLevelService {
  static final FirebaseLevelService _instance = FirebaseLevelService._internal();
  factory FirebaseLevelService() => _instance;
  FirebaseLevelService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // High-performance in-memory cache to eliminate redundant network overhead
  final Map<int, Map<String, dynamic>> _levelCache = {};

  /// Restores cached levels from SharedPreferences to in-memory cache for instant offline access.
  Future<void> initCacheFromPrefs() async {
    if (_levelCache.isNotEmpty) return; // Already initialized in memory
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int count = 0;
      for (var key in keys) {
        if (key.startsWith('cached_level_')) {
          final levelNum = int.tryParse(key.replaceAll('cached_level_', ''));
          final jsonStr = prefs.getString(key);
          if (levelNum != null && jsonStr != null) {
            _levelCache[levelNum] = jsonDecode(jsonStr);
            count++;
          }
        }
      }
      if (count > 0) {
        print('Offline Cache: Restored $count levels from SharedPreferences successfully!');
      }
    } catch (e) {
      print('Offline Cache Restore Error: $e');
    }
  }

  /// Persists a single level data map to SharedPreferences.
  Future<void> _saveLevelToPrefs(int levelNumber, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_level_$levelNumber', jsonEncode(data));
    } catch (e) {
      print('Offline Cache Save Error for level $levelNumber: $e');
    }
  }

  /// Fetches a level by its number from Firestore with caching and timeout optimization.
  Future<Map<String, dynamic>?> fetchLevel(int levelNumber) async {
    // 1. Instantly load locally saved levels if not already initialized
    await initCacheFromPrefs();

    // 2. Instant Memory Cache lookup (0% CPU/Network usage)
    if (_levelCache.containsKey(levelNumber)) {
      return _levelCache[levelNumber];
    }

    try {
      // 3. Fetch with 5s timeout and intelligent source selection (serverAndCache)
      final doc = await _firestore
          .collection('levels')
          .doc('level_$levelNumber')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _levelCache[levelNumber] = data; // Store in memory
        await _saveLevelToPrefs(levelNumber, data); // Save to local storage for offline use
        return data;
      }
    } catch (e) {
      print('Firebase fetch optimized fallback: $e');
    }
    return null;
  }

  /// Preloads all levels from Firestore in a single query and caches them in memory and SharedPreferences.
  /// Typically called during the splash/loading screen.
  Future<void> preloadAllLevels() async {
    // 1. Instantly load previously cached levels for zero-wait boot
    await initCacheFromPrefs();

    // 2. Query Firestore collection in background to sync changes/additions
    try {
      final querySnapshot = await _firestore
          .collection('levels')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));

      int count = 0;
      for (var doc in querySnapshot.docs) {
        final docId = doc.id; // e.g. "level_1"
        final levelNum = int.tryParse(docId.replaceAll('level_', ''));
        if (levelNum != null && doc.data().isNotEmpty) {
          _levelCache[levelNum] = doc.data();
          await _saveLevelToPrefs(levelNum, doc.data()); // Persist to local storage
          count++;
        }
      }
      print('Successfully synchronized and persisted $count levels from Firestore!');
    } catch (e) {
      print('Firebase preload all levels optimized fallback: $e');
    }
  }

  /// Dynamically determines the total number of levels available in Firestore.
  Future<int> getTotalLevelCount() async {
    try {
      final snapshot = await _firestore.collection('levels').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting total level count: $e');
      return 0; // Fallback to 0, which will trigger local fallback logic
    }
  }

  /// Optional: Helper method to upload a local level file to Firestore.
  /// Useful for the initial setup.
  Future<void> uploadLevel(int levelNumber, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('levels').doc('level_$levelNumber').set(data);
      print('Level $levelNumber uploaded successfully!');
    } catch (e) {
      print('Error uploading level $levelNumber: $e');
    }
  }
}
