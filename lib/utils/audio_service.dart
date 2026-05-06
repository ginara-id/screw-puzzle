import 'package:flame_audio/flame_audio.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  bool isMuted = false;

  // Initialize and cache sounds
  Future<void> init() async {
    try {
      await FlameAudio.bgm.initialize();
      await FlameAudio.audioCache.loadAll([
        'bgm_menu.wav',
        'bgm_game.wav',
        'bolt_tap.wav',
        'bolt_snap.wav',
        'plate_collision.wav',
        'victory.wav',
        'game_over.wav',
        'booster_click.wav',
      ]);
    } catch (e) {
      print('AudioService: Some audio assets are missing. Please add them to assets/audio/');
    }
  }

  // BGM Management
  void playMenuBGM() {
    if (isMuted) return;
    try {
      FlameAudio.bgm.play('bgm_menu.wav', volume: 0.5);
    } catch (e) {
      print('AudioService: bgm_menu.wav not found');
    }
  }

  void playGameBGM() {
    if (isMuted) return;
    try {
      FlameAudio.bgm.play('bgm_game.wav', volume: 0.4);
    } catch (e) {
      print('AudioService: bgm_game.wav not found');
    }
  }

  void stopBGM() {
    try {
      FlameAudio.bgm.stop();
    } catch (e) {}
  }

  // SFX Management
  void playSfx(String fileName, {double volume = 1.0}) {
    if (isMuted) return;
    try {
      FlameAudio.play(fileName, volume: volume);
    } catch (e) {
      // Silently fail if SFX is missing
    }
  }

  void playBoltTap() => playSfx('bolt_tap.wav', volume: 0.6);
  void playBoltSnap() => playSfx('bolt_snap.wav', volume: 0.8);
  void playPlateCollision({double volume = 0.5}) => playSfx('plate_collision.wav', volume: volume);
  void playVictory() => playSfx('victory.wav', volume: 0.7);
  void playGameOver() => playSfx('game_over.wav', volume: 0.7);
  void playBoosterClick() => playSfx('booster_click.wav', volume: 0.5);

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      stopBGM();
    } else {
      playMenuBGM();
    }
  }
}
