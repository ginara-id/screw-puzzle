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
    try {
      // 1. Initialize BGM
      await FlameAudio.bgm.initialize();
      
      // 2. Pre-load pools for EVERY frequent sound
      // This "burns" the players into memory once, preventing dynamic allocation/leakage
      _pools['bolt_tap.wav'] = await FlameAudio.createPool('bolt_tap.wav', minPlayers: 1, maxPlayers: 3);
      _pools['bolt_snap.wav'] = await FlameAudio.createPool('bolt_snap.wav', minPlayers: 1, maxPlayers: 2);
      _pools['plate_collision.wav'] = await FlameAudio.createPool('plate_collision.wav', minPlayers: 1, maxPlayers: 4);
      _pools['booster_click.wav'] = await FlameAudio.createPool('booster_click.wav', minPlayers: 1, maxPlayers: 1);
      
      // Cache large win/lose states too into pools to completely kill native MediaPlayer spawning
      _pools['victory.wav'] = await FlameAudio.createPool('victory.wav', minPlayers: 1, maxPlayers: 1);
      _pools['game_over.wav'] = await FlameAudio.createPool('game_over.wav', minPlayers: 1, maxPlayers: 1);

      // 3. Cache only continuous BGM
      await FlameAudio.audioCache.loadAll([
        'bgm_menu.wav',
        'bgm_game.wav',
      ]);
    } catch (e) {
      print('AudioService Critical Init Error: $e');
    }
  }

  // --- BGM Management ---
  
  String? _currentBgm;

  void _playBgm(String fileName, double volume) {
    if (isMuted) return;
    if (_currentBgm == fileName && FlameAudio.bgm.isPlaying) return;
    
    try {
      _currentBgm = fileName;
      FlameAudio.bgm.play(fileName, volume: volume);
    } catch (e) {
      print('BGM Error: $e');
    }
  }

  void playMenuBGM() => _playBgm('bgm_menu.wav', 0.4);
  void playGameBGM() => _playBgm('bgm_game.wav', 0.3);

  void stopBGM() {
    _currentBgm = null;
    try {
      FlameAudio.bgm.stop();
    } catch (e) {}
  }

  // --- SFX Management ---

  void playSfx(String fileName, {double volume = 1.0, int? throttleMs}) {
    if (isMuted) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastPlay = _lastPlayTimes[fileName] ?? 0;
    final wait = throttleMs ?? _defaultThrottleMs;

    if (now - lastPlay < wait) return;
    _lastPlayTimes[fileName] = now;

    try {
      final pool = _pools[fileName];
      if (pool != null) {
        // High performance path: Reuse player from pool
        pool.start(volume: volume);
      } else {
        // Rare path: Play one-off and let Flame handle cleanup
        unawaited(FlameAudio.play(fileName, volume: volume));
      }
    } catch (e) {
      // Audio errors should never crash the game
      print('SFX Error ($fileName): $e');
    }
  }

  void playBoltTap() => playSfx('bolt_tap.wav', volume: 0.5);
  void playBoltSnap() => playSfx('bolt_snap.wav', volume: 0.7);
  void playBoltScrape() => playSfx('bolt_tap.wav', volume: 0.3); // Reusing tap for now
  
  void playPlateCollision({double volume = 0.4}) {
    // Randomize volume slightly for "natural" feel
    final variedVolume = (volume * 0.8) + (Random().nextDouble() * volume * 0.4);
    playSfx('plate_collision.wav', volume: variedVolume.clamp(0.1, 1.0), throttleMs: _collisionThrottleMs);
  }

  void playVictory() => playSfx('victory.wav', volume: 0.6, throttleMs: 3000);
  void playGameOver() => playSfx('game_over.wav', volume: 0.6, throttleMs: 3000);
  void playBoosterClick() => playSfx('booster_click.wav', volume: 0.4);

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      stopBGM();
    } else {
      playMenuBGM();
    }
  }
}
