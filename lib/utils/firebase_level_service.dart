import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class FirebaseLevelService {
  static final FirebaseLevelService _instance = FirebaseLevelService._internal();
  factory FirebaseLevelService() => _instance;
  FirebaseLevelService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // High-performance in-memory cache to eliminate redundant network overhead
  final Map<int, Map<String, dynamic>> _levelCache = {};

  /// Fetches a level by its number from Firestore with caching and timeout optimization.
  Future<Map<String, dynamic>?> fetchLevel(int levelNumber) async {
    // 1. Instant Memory Cache lookup (0% CPU/Network usage)
    if (_levelCache.containsKey(levelNumber)) {
      return _levelCache[levelNumber];
    }

    try {
      // 2. Fetch with 5s timeout and intelligent source selection (serverAndCache)
      // This prevents the app from hanging on the loading screen if the connection is slow.
      final doc = await _firestore
          .collection('levels')
          .doc('level_$levelNumber')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _levelCache[levelNumber] = data; // Store for future instant access
        return data;
      }
    } catch (e) {
      print('Firebase fetch optimized fallback: $e');
    }
    return null;
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
