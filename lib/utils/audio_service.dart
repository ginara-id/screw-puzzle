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
      // Initialize BGM. FlameAudio.bgm handles background music via streaming,
      // which is highly efficient and prevents memory leaks / performance lag.
      FlameAudio.bgm.initialize();
    } catch (e) {
      print('Audio init error: $e');
    }
  }

  // --- BGM Management ---
  
  String? _currentBgm;
  double _currentBgmVolume = 0.0;
  int _fadeId = 0;

  Future<void> _playBgm(String fileName, double targetVolume) async {
    if (isMuted) return;
    
    if (_currentBgm == fileName) {
      // If same track is playing, just smoothly transition to the new volume!
      _fadeToVolume(targetVolume, durationMs: 1500);
      return;
    }
    
    try {
      if (_currentBgm != null) {
        await FlameAudio.bgm.stop();
      }
      
      _currentBgmVolume = 0.0;
      await FlameAudio.bgm.play(fileName, volume: 0.0);
      _currentBgm = fileName;
      
      _fadeToVolume(targetVolume, durationMs: 2500);
    } catch (e) {
      print('BGM Error: $e');
    }
  }

  void _fadeToVolume(double targetVolume, {int durationMs = 1500}) {
    final currentFadeId = ++_fadeId;
    final int steps = durationMs ~/ 50; // Update every 50ms for ultra-smoothness
    final double volumeStep = (targetVolume - _currentBgmVolume) / steps;
    
    Future(() async {
      for (int i = 0; i < steps; i++) {
        if (_fadeId != currentFadeId || isMuted || _currentBgm == null) break;
        _currentBgmVolume += volumeStep;
        // Safeguard clamps
        if (_currentBgmVolume < 0) _currentBgmVolume = 0;
        if (_currentBgmVolume > 1) _currentBgmVolume = 1;
        
        FlameAudio.bgm.audioPlayer.setVolume(_currentBgmVolume);
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Finalize the target volume accurately
      if (_fadeId == currentFadeId && !isMuted && _currentBgm != null) {
        _currentBgmVolume = targetVolume;
        FlameAudio.bgm.audioPlayer.setVolume(_currentBgmVolume);
      }
    });
  }

  void playMenuBGM() => _playBgm('bgm.mp3', 0.4);
  void playGameBGM() => _playBgm('bgm.mp3', 0.12); // Significantly lower volume in-game
  void muteBgmForTransition() => _fadeToVolume(0.0, durationMs: 400);

  Future<void> stopBGM() async {
    if (_currentBgm != null) {
      try {
        await FlameAudio.bgm.stop();
        _currentBgm = null;
      } catch (e) {
        print('Stop BGM Error: $e');
      }
    }
  }

  // --- SFX Management ---

  void playSfx(String fileName, {double volume = 1.0, int? throttleMs}) async {
    if (isMuted) return;

    // Track play times to prevent audio stacking (ear bleeding / lag)
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastPlayTimes[fileName] ?? 0;
    final throttle = throttleMs ?? _defaultThrottleMs;

    if (now - lastTime < throttle) return;
    _lastPlayTimes[fileName] = now;

    try {
      // Use AudioPool for SFX: caches audio and limits concurrent instances
      // This is the correct way to prevent OOM memory leaks on Android
      if (!_pools.containsKey(fileName)) {
        _pools[fileName] = await FlameAudio.createPool(fileName, maxPlayers: 3);
      }
      _pools[fileName]?.start(volume: volume);
    } catch (e) {
      print('SFX Error ($fileName): $e');
    }
  }

  void playBoltTap() => playSfx('bolt_tap.wav', volume: 0.5);
  void playRustTap() => playSfx('rusty.mp3', volume: 0.7, throttleMs: 80); // Throttle slightly to allow rapid tapping without overflowing AudioPool
  void playBoltSnap() => playSfx('bolt_snap.wav', volume: 0.7);
  void playBoltScrape() => playSfx('scrape.wav', volume: 0.4, throttleMs: 100); 
  void playPickScrew() => playSfx('pick.wav', volume: 0.8, throttleMs: 50);
  void playDropScrew() => playSfx('drop.wav', volume: 0.9, throttleMs: 50);
  void playLightningStrike() => playSfx('lightning.wav', volume: 0.9, throttleMs: 250);
  void playIceFreeze() => playSfx('ice.mp3', volume: 0.85, throttleMs: 2000);
  void playSmashPlate() => playSfx('smash.mp3', volume: 1.0, throttleMs: 500);
  void playGateOpen() => playSfx('gate_open.wav', volume: 0.85, throttleMs: 1000);
  void playGateClose() => playSfx('gate_close.wav', volume: 0.9, throttleMs: 1000);
  
  void playPlateCollision({double volume = 0.4}) {
    playSfx('collide.wav', volume: volume, throttleMs: _collisionThrottleMs);
  }

  void playVictory() => playSfx('victory.wav', volume: 0.6, throttleMs: 3000);
  void playGameOver() => playSfx('game_over.wav', volume: 0.6, throttleMs: 3000);
  void playTimeWarningTick() => playSfx('tick.wav', volume: 0.7);
  void playBoosterClick() => playSfx('booster_click.wav', volume: 0.4);

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      stopBGM();
    } else {
      if (_currentBgm != null) {
        final bgm = _currentBgm!;
        _currentBgm = null;
        _playBgm(bgm, 0.4);
      } else {
        playMenuBGM();
      }
    }
  }
}
