import 'package:flame_audio/flame_audio.dart';
import 'dart:async';
import 'dart:math';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  bool isMuted = false;
  
  // Audio Pools for high-frequency SFX. 
  // Reusing players is the ONLY way to prevent memory leaks in Flame/Android.
  final Map<String, AudioPool> _pools = {};

  // Track last play time to prevent "Audio Stacking" (Ear bleeding/CPU spikes)
  final Map<String, int> _lastPlayTimes = {};
  static const int _defaultThrottleMs = 120; // Enough for human ear, good for CPU
  static const int _collisionThrottleMs = 150; 

  // Initialize and cache sounds
  Future<void> init() async {
    // DISABLED FOR DIAGNOSTICS
    return;
  }

  // --- BGM Management ---
  
  String? _currentBgm;

  void _playBgm(String fileName, double volume) {
    // DISABLED FOR DIAGNOSTICS
  }

  void playMenuBGM() => _playBgm('bgm_menu.wav', 0.4);
  void playGameBGM() => _playBgm('bgm_game.wav', 0.3);

  void stopBGM() {
    // DISABLED FOR DIAGNOSTICS
  }

  // --- SFX Management ---

  void playSfx(String fileName, {double volume = 1.0, int? throttleMs}) {
    // DISABLED FOR DIAGNOSTICS
  }

  void playBoltTap() => playSfx('bolt_tap.wav', volume: 0.5);
  void playBoltSnap() => playSfx('bolt_snap.wav', volume: 0.7);
  void playBoltScrape() => playSfx('bolt_tap.wav', volume: 0.3); 
  
  void playPlateCollision({double volume = 0.4}) {
    // DISABLED FOR DIAGNOSTICS
  }

  void playVictory() => playSfx('victory.wav', volume: 0.6, throttleMs: 3000);
  void playGameOver() => playSfx('game_over.wav', volume: 0.6, throttleMs: 3000);
  void playBoosterClick() => playSfx('booster_click.wav', volume: 0.4);

  void toggleMute() {
  }
}
