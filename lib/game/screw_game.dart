import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;
import 'package:flame_audio/flame_audio.dart'; // Forced import to stop previous streams
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/bolt_component.dart';
import '../components/plate_component.dart';
import '../components/hole_component.dart';
import '../components/background_component.dart';

import '../components/industrial_transition.dart';
import '../components/level_clear_effect.dart';
import '../components/timer_text.dart';
import '../utils/level_manager.dart';
import '../utils/audio_service.dart';
import '../utils/ad_service.dart';
import '../utils/firebase_level_service.dart';
import '../utils/lang_service.dart';

enum TutorialStep {
  welcome,
  explainTimer,
  selectLeftBolt,
  moveLeftBolt,
  selectRightBolt,
  moveRightBolt,
  explainSwing,
  selectCenterBolt,
  moveCenterBolt,
  
  // Level 2: Interactive Booster Trials
  explainRust,
  selectTutorialRustBolt,
  moveTutorialRustBolt,
  introBoosters,
  tryStorm,
  explainSmash,
  trySmash,
  explainChronos,
  tryChronos,
}

class ScrewPuzzleGame extends Forge2DGame {
  late final LevelManager levelManager;
  final audio = AudioService();
  int currentLevel = 1;
  int highestUnlockedLevel = 1;
  int totalLevelsAvailable = 10; // Cached from Firebase or local
  final timeBonusNotifier = ValueNotifier<double>(0.0); // Kept for internal trigger
  final comboUpdateNotifier = ValueNotifier<double>(0.0); // Smooth broadcast of decay bar
  final tutorialStepNotifier = ValueNotifier<TutorialStep?>(null);
  bool hasActiveBannerAd = false;

  // Collision Categories
  static const int kPlateCategory = 0x0001;
  static const int kBoltHoleCategory = 0x0002;

  // Interaction State
  BoltComponent? _activeBolt;
  BoltComponent? get activeBolt => _activeBolt;
  int get remainingPlates => world.children.whereType<PlateComponent>().length;

  bool isHoleBlocked(HoleComponent hole) {
    for (final plate in world.children.whereType<PlateComponent>()) {
      if (plate.isOverlappingCircle(hole.position, hole.radius)) {
        // Strict, realistic tolerance ensuring holes must be almost perfectly aligned (max 20% of radius overlap)
        if (!plate.isHoleAligned(hole.position, tolerance: 0.08)) {
          return true;
        }
      }
    }
    return false;
  }

  final _boltJoints = <BoltComponent, List<RevoluteJoint>>{};
  final _boltToHole = <BoltComponent, HoleComponent>{};
  final _holes = <HoleComponent>[];

  HoleComponent? pendingAdHole;
  String? pendingAdBooster;

  // BOOSTER INVENTORY SYSTEM (Unlocked after Level 2 tutorial)
  final stormCountNotifier = ValueNotifier<int>(2);
  final smashCountNotifier = ValueNotifier<int>(2);
  final chronosCountNotifier = ValueNotifier<int>(2);
  final alertNotifier = ValueNotifier<String?>(null);
  final rustTutorialHitsNotifier = ValueNotifier<int>(6);

  // RETENTION OPTIMIZATION: Regulate interstitial ad frequency pacing
  int _gamesSinceLastInterstitial = 0;

  ScrewPuzzleGame() : super(gravity: Vector2(0, 14.0)) {
    // OPTIMIZATION: Reduced iteration counts from excessively heavy 25 to robust 8.
    // This gives a MASSIVE 300% physics CPU runtime boost and stops frame-blocking.
    velocityIterations = 8;
    positionIterations = 8;
  }

  // --- ULTIMATE FLUIDITY FIX: Fixed Timestep Accumulator ---
  // Decouples the physics world progression from variable Android frame refresh rates.
  // Eliminates micro-lag and frame skipping during fast movement.
  double _physicsAccumulator = 0.0;
  static const double _fixedTimeStep = 1.0 / 60.0;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // FORCED MASTER KILL FOR DIAGNOSTICS: Terminate any zombie native audio threads
    try {
      FlameAudio.bgm.stop();
    } catch (e) {
      // Silently continue if not playing
    }

    // Initialize Audio (Currently dummy/empty in diagnostic mode)
    await audio.init();
    audio.playMenuBGM();

    // 0. Static Background
    await add(BackgroundComponent());

    camera.viewfinder
      ..zoom = 35.0
      ..position = Vector2(0, 22.0); // Lifted to accommodate bottom ad

    levelManager = LevelManager(this);

    // PERSISTENCE: Load progress
    final prefs = await SharedPreferences.getInstance();
    highestUnlockedLevel = prefs.getInt('current_level') ?? 1;
    currentLevel = highestUnlockedLevel;

    // Fetch total levels available for progression logic
    final count = await FirebaseLevelService().getTotalLevelCount();
    if (count > 0) {
      totalLevelsAvailable = count;
    }
    
    // Load booster inventory
    stormCountNotifier.value = prefs.getInt('booster_storm') ?? 2;
    smashCountNotifier.value = prefs.getInt('booster_smash') ?? 2;
    chronosCountNotifier.value = prefs.getInt('booster_chronos') ?? 2;

    // Initial Level Load without transition
    await levelManager.loadLevel(
      currentLevel,
      transitionMode: TransitionMode.none,
    );

    // Show Main Menu initially
    overlays.add('MainMenu');
  }

  double _lastShakeTime = 0;
  void shakeCamera({double intensity = 0.5, double duration = 0.2}) {
    // Cooldown: Don't shake too often (max once every 0.5 seconds)
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (now - _lastShakeTime < 0.5) return;
    _lastShakeTime = now;

    camera.viewfinder.add(
      MoveEffect.by(
        Vector2(intensity, intensity),
        EffectController(
          duration: duration / 4,
          reverseDuration: duration / 4,
          repeatCount: 2,
          curve: Curves.bounceIn,
        ),
      ),
    );
  }

  bool _isVictoryTriggered = false;

  // TIMER SYSTEM
  double _levelTimeLimit = 120.0; // Tracking current level total
  double _remainingTime = 120.0;
  bool _isGameOver = false;
  bool get isGameOver => _isGameOver;
  double get remainingTime => _remainingTime;

  void setLevelTimeLimit(double seconds) {
    _levelTimeLimit = seconds;
    _remainingTime = seconds;
  }

  Future<void> saveBoosterInventory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('booster_storm', stormCountNotifier.value);
      await prefs.setInt('booster_smash', smashCountNotifier.value);
      await prefs.setInt('booster_chronos', chronosCountNotifier.value);
    } catch (e) {
      print('Failed to save booster inventory: $e');
    }
  }

  /// RETENTION FRIENDLY INTERSTITIALS:
  /// Prioritizes user retention by introducing levels 1-3 ad-free gating, 
  /// and frequency limiting ads to only 1 every 2 completed games.
  void triggerInterstitialWithPacing(VoidCallback onComplete) {
    print('\n=== 🛡️ [AD_PACS] MEMULAI EVALUASI IKLAN INTERSTITIAL ===');
    print('📄 Level Saat Ini: $currentLevel');
    
    // GATE 1: Level Restriction Check (Safe Early Level Gating)
    // Memblokir total iklan di Level 1, 2, dan 3 demi mengamankan impresi pertama pemain.
    if (currentLevel <= 3) {
      print('⛔ [AD_PACS] DILEWATI: Level $currentLevel <= 3 dijamin 100% bebas iklan demi retensi awal.');
      print('====================================================\n');
      onComplete();
      return;
    }

    _gamesSinceLastInterstitial++;
    print('📈 Hitung Game Sejak Iklan Terakhir: $_gamesSinceLastInterstitial / 2 (Target)');

    // GATE 2: Frequency Cap Check (Production Pacing)
    // Iklan hanya boleh terbit tepat setiap 2 kali babak selesai secara berkala.
    if (_gamesSinceLastInterstitial >= 2) {
      print('🎬 [AD_PACS] DISETUJUI: Memuat & Menampilkan Iklan Layar Penuh...');
      _gamesSinceLastInterstitial = 0;
      
      AdService().showInterstitialAd(
        onAdDismissed: () {
          print('✅ [AD_PACS] SELESAI: Iklan ditutup. Membuka Menu Game Akhir.');
          print('====================================================\n');
          onComplete();
        },
      );
    } else {
      print('⏳ [AD_PACS] DILEWATI: Pacing belum terpenuhi ($_gamesSinceLastInterstitial/2). Kenyamanan user terjaga.');
      print('====================================================\n');
      onComplete();
    }
  }

  /// Triggers a HUD alert message with negative feedback chime.
  void triggerAlert(String message) {
    alertNotifier.value = message;
    audio.playBoltSnap(); // Deny snap feedback!
    
    // Auto-clears the message after 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (alertNotifier.value == message) {
        alertNotifier.value = null;
      }
    });
  }

  bool _isTimeFrozen = false;
  final timeFrozenNotifier = ValueNotifier<bool>(false);
  double _freezeDurationRemaining = 0.0;
  final freezeDurationNotifier = ValueNotifier<double>(0.0);
  double _victoryCheckTimer = 0;

  // COMBO SYSTEM
  double _lastMoveTime = 0;
  int _comboCount = 0;
  static const double comboWindow = 2.0; // Mempersingkat jendela kombo menjadi 2.0 detik agar lebih menantang dan dinamis
  
  // AUDIO TRACKING
  int _lastTickSecond = -1;

  int get comboCount => _comboCount;
  double get lastMoveTime => _lastMoveTime;
  double get comboPercent => (1.0 - (_lastMoveTime / comboWindow)).clamp(0.0, 1.0);

  @override
  void update(double dt) {
    // 1. FIXED TIMESTEP ACCUMULATOR:
    // Decouples physics world steps from variable frame rendering rates.
    // This removes jerky increments ("deg-deg") and produces fluid, continuous plate motion ("serr")!
    final clampedDt = dt.clamp(0.0, 0.25);
    _physicsAccumulator += clampedDt;

    int steps = 0;
    while (_physicsAccumulator >= _fixedTimeStep && steps < 5) {
      super.update(_fixedTimeStep);
      _physicsAccumulator -= _fixedTimeStep;
      steps++;
    }

    // 2. REAL-WORLD GAME LOGIC UPDATES:
    _lastMoveTime += dt;

    // Reset combo if idle for too long
    if (_lastMoveTime > comboWindow) {
      _comboCount = 0;
    }
    
    comboUpdateNotifier.value = (_comboCount > 0) ? comboPercent : 0.0;

    final isInGame = overlays.isActive('HUD') && !overlays.isActive('MainMenu');

    // --- ABSOLUTE REAL-TIME CLOCK: Subtracts raw wall-clock time ---
    final isTutorialActive = tutorialStepNotifier.value != null;
    if (isInGame && !_isVictoryTriggered && !_isGameOver && !_isTimeFrozen && !isTutorialActive) {
      _remainingTime -= dt; // USES UNCLAMPED REAL-TIME VALUE!
      if (_remainingTime <= 0) {
        _remainingTime = 0;
        _triggerGameOver();
      }

      // Audio warning tick precisely once per second
      if (_remainingTime <= 10.0 && _remainingTime > 0) {
        final currentSecond = _remainingTime.toInt();
        if (currentSecond != _lastTickSecond) {
          _lastTickSecond = currentSecond;
          audio.playTimeWarningTick();
        }
      } else {
        _lastTickSecond = -1;
      }
    }

    // --- DYNAMIC BOOST FREEZE COUNTDOWN ---
    if (isInGame && _isTimeFrozen && !_isVictoryTriggered && !_isGameOver) {
      _freezeDurationRemaining -= dt;
      if (_freezeDurationRemaining <= 0) {
        _freezeDurationRemaining = 0;
        _isTimeFrozen = false;
        timeFrozenNotifier.value = false;
        audio.playBoltSnap(); // Return to normal time chime!
      }
      freezeDurationNotifier.value = _freezeDurationRemaining;
    }

    // --- THROTTLED CHECKS: CPU savings throttled check ---
    _victoryCheckTimer += dt;
    if (_victoryCheckTimer < 0.1) return;
    _victoryCheckTimer = 0;

    final plates = world.children.whereType<PlateComponent>();

    if (isInGame && plates.isEmpty && !_isVictoryTriggered) {
      _triggerVictorySequence();
      return;
    }

    final viewportHeight = camera.viewport.size.y / camera.viewfinder.zoom;
    // ABSOLUTE VISUAL BOTTOM: Exact camera frustum edge 
    final bottomEdge = camera.viewfinder.position.y + (viewportHeight / 2);

    // PERFORMANCE: Remove plates the INSTANT they drop behind the bottom HUD overlay
    for (final plate in plates.toList()) {
      // Trigger exactly when plate's center dips below the top of bottom dock area!
      if (plate.body.position.y > bottomEdge - 2.0) {
        // COMBO INCREMENT REMOVED FROM HERE PER USER REQUEST

        // VIEWPORT FIX: The plate is 8m below the screen! 
        // We MUST clamp the spawn point so it is visible INSIDE the screen bottom edge!
        final spawnPos = Vector2(
          plate.body.position.x.clamp(-4.0, 4.0), // Constrain horizontally
          camera.viewfinder.position.y + (viewportHeight / 2) - 6.0 // Rise up from inside bottom edge
        );

        // 1. ONLY SHOW COMBO VFX IF > 1 (Per user instruction)
        if (_comboCount > 1) {
          showComboEffect(spawnPos, _comboCount);
        }

        // 2. COMBO TIME BONUS: Minimum 1.0s, otherwise 1.0s per multiplier tier 
        final double timeBonus = math.max(1.0, 1.0 * _comboCount);
        _remainingTime += timeBonus;
        
        // Always show small floating time addition text for reward feedback
        showTimeBonusEffect(spawnPos, timeBonus);
        
        // Notify Flutter just in case (for potential HUD effects)
        timeBonusNotifier.value = timeBonus;

        // HapticFeedback.lightImpact(); DISABLED
        plate.removeFromParent();
      }
    }

    final allOffScreen =
        plates.isNotEmpty &&
        plates.every((p) => p.body.position.y > bottomEdge);

    if (isInGame && allOffScreen && !_isVictoryTriggered) {
      _triggerVictorySequence();
    }
  }

  void _triggerGameOver() {
    if (_isGameOver || _isVictoryTriggered) return;
    _isGameOver = true;
    
    audio.playGameOver();

    // Close the heavy industrial doors, then show the game over menu!
    camera.viewport.add(
      IndustrialTransitionComponent(
        mode: TransitionMode.closeOnly,
        onHalfway: () async {
          if (!overlays.isActive('GameOverMenu')) {
            triggerInterstitialWithPacing(() {
              overlays.add('GameOverMenu');
            });
          }
        },
      ),
    );
  }

  // Removed old static showScoreEffect

  void _triggerVictorySequence() {
    if (_isVictoryTriggered || _isGameOver || overlays.isActive('WinMenu')) return;
    _isVictoryTriggered = true;

    // Spawn the level clear effect (sparks/shockwave) right on the screen center
    camera.viewport.add(LevelClearEffect());

    // Close the heavy industrial doors, then show the win menu!
    audio.playVictory();
    camera.viewport.add(
      IndustrialTransitionComponent(
        mode: TransitionMode.closeOnly,
        onHalfway: () async {
          if (!overlays.isActive('WinMenu')) {
            triggerInterstitialWithPacing(() {
              overlays.add('WinMenu');
            });
          }
        },
      ),
    );
  }

  void showSteamTransition(
    Future<void> Function() onHalfway, {
    TransitionMode mode = TransitionMode.closeAndOpen,
  }) {
    camera.viewport.children.whereType<IndustrialTransitionComponent>().forEach(
      (c) => c.removeFromParent(),
    );
    camera.viewport.add(
      IndustrialTransitionComponent(onHalfway: onHalfway, mode: mode),
    );
  }

  // --- Level Flow ---

  Future<void> nextLevel() async {
    _isVictoryTriggered = false;
    _clearTimeFreeze();
    // Logic: Only advance highestUnlockedLevel if we completed our furthest level
    if (currentLevel == highestUnlockedLevel) {
      highestUnlockedLevel++;
      // PERSISTENCE: Save progress
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_level', highestUnlockedLevel);
    }

    // Move to the next level number
    currentLevel++;

    // Check if we reached the end of available content
    if (currentLevel > totalLevelsAvailable) {
      // No more levels! Go back to menu
      overlays.remove('HUD');
      overlays.add('MainMenu');
      audio.playMenuBGM();
      return;
    }

    levelManager.loadLevel(
      currentLevel,
      transitionMode: TransitionMode.openOnly,
    );
  }

  void resetLevel({TransitionMode mode = TransitionMode.closeAndOpen}) {
    if (!_isVictoryTriggered && !_isGameOver) {
      triggerInterstitialWithPacing(() {
        _isVictoryTriggered = false;
        _isGameOver = false;
        _clearTimeFreeze();
        _remainingTime = _levelTimeLimit; // Uses custom time limit from JSON
        levelManager.loadLevel(currentLevel, transitionMode: mode);
      });
      return;
    }

    _isVictoryTriggered = false;
    _isGameOver = false;
    _clearTimeFreeze();
    _remainingTime = _levelTimeLimit; // Uses custom time limit from JSON
    levelManager.loadLevel(currentLevel, transitionMode: mode);
  }

  void _clearTimeFreeze() {
    _isTimeFrozen = false;
    timeFrozenNotifier.value = false;
    _freezeDurationRemaining = 0.0;
    freezeDurationNotifier.value = 0.0;
  }

  /// SPECIAL ABILITY: Unleashes a lightning storm that clears all Rust from bolts sequentially.
  Future<void> useRustCleanseBooster() async {
    if (_isGameOver || _isVictoryTriggered) return;

    final rustyBolts = world.children
        .whereType<BoltComponent>()
        .where((b) => b.isRusty)
        .toList();

    if (rustyBolts.isEmpty) {
      triggerAlert(LangService.t('hud_alert_storm_no_rust'));
      return;
    }

    final isTutorialActive = tutorialStepNotifier.value != null;
    if (!isTutorialActive) {
      if (stormCountNotifier.value <= 0) {
        pendingAdBooster = 'STORM';
        overlays.add('AdConfirmation');
        return;
      }
      stormCountNotifier.value--;
      saveBoosterInventory();
    }

    final isTutorial = tutorialStepNotifier.value == TutorialStep.tryStorm;
    if (isTutorial) {
      tutorialStepNotifier.value = null; // Temporarily hide UI so player sees visual lightning effects clearly!
    }

    // 1. INJECT MASTER FLASH (Sets the initial thunder atmosphere)
    camera.viewport.add(LightningFlashComponent());

    // 2. SEQUENTIAL ARMAGEDDON: Iterate one by one with visual impact
    final rnd = math.Random();

    for (final bolt in rustyBolts) {
      // Quick small lightning impact audio for each
      audio.playLightningStrike(); // Dynamic thunder clap

      // Identify where the sky is relative to current camera
      final worldPos = bolt.body.position;

      // Spawn lightning strike running from the heavens down to this specific bolt
      final skyStart = Vector2(
        worldPos.x + ((rnd.nextDouble() - 0.5) * 4), // Staggered chaotic origin
        worldPos.y - 16.0, // Far off top edge of camera viewport
      );

      // Add explicit Lightning line from top to bolt
      world.add(LightningStrikeComponent(startPos: skyStart, endPos: worldPos));

      // Clean the bolt!
      bolt.cureRust();

      // Generate standard electric particle cloud at point of impact
      createSparks(worldPos, isLightning: true);

      // Wait a small satisfying fraction of a second before striking the next target
      await Future.delayed(const Duration(milliseconds: 350));

      // Safety stop if level changed mid-sequence
      if (_isGameOver || _isVictoryTriggered) break;
    }

    // Final confirmation chime when complete!
    audio.playSfx('victory.wav', volume: 0.7);

    // TUTORIAL PROGRESSION
    if (isTutorial) {
      tutorialStepNotifier.value = TutorialStep.explainSmash;
    }
  }

  Future<void> useTimeFreezeBooster() async {
    if (_isGameOver || _isVictoryTriggered || _isTimeFrozen) return;

    final isTutorialActive = tutorialStepNotifier.value != null;
    if (!isTutorialActive) {
      if (chronosCountNotifier.value <= 0) {
        pendingAdBooster = 'CHRONOS';
        overlays.add('AdConfirmation');
        return;
      }
      chronosCountNotifier.value--;
      saveBoosterInventory();
    }

    _isTimeFrozen = true;
    _freezeDurationRemaining = 10.0;
    freezeDurationNotifier.value = 10.0;
    timeFrozenNotifier.value = true;
    audio.playBoosterClick();
    audio.playIceFreeze(); // Use the optimized ice.mp3 memory-safe effect

    // TUTORIAL PROGRESSION
    if (tutorialStepNotifier.value == TutorialStep.tryChronos) {
      tutorialStepNotifier.value = null;
      overlays.remove('Tutorial');
    }
  }

  /// SPECIAL ABILITY: Destroys a random plate from the board to help unblock.
  void usePlateSmashBooster() {
    if (_isGameOver || _isVictoryTriggered) return;

    final plates = world.children.whereType<PlateComponent>().toList();
    if (plates.isEmpty) {
      audio.playBoosterClick();
      return;
    }

    final isTutorialActive = tutorialStepNotifier.value != null;
    if (!isTutorialActive) {
      if (smashCountNotifier.value <= 0) {
        pendingAdBooster = 'SMASH';
        overlays.add('AdConfirmation');
        return;
      }
      smashCountNotifier.value--;
      saveBoosterInventory();
    }

    final isTutorial = tutorialStepNotifier.value == TutorialStep.trySmash;
    if (isTutorial) {
      tutorialStepNotifier.value = null; // Hides overlay so player sees the explosion!
    }

    // TARGETING: Pick the plate with the fewest joints (easiest to remove)
    plates.sort((a, b) => _plateJointCount(a).compareTo(_plateJointCount(b)));
    final target = plates.first;

    // EXPLOSION EFFECT
    showSmashEffect(target.body.position);
    audio.playSmashPlate();
    shakeCamera(intensity: 1.5, duration: 0.5);

    // Remove joints first
    for (final joints in _boltJoints.values) {
      joints.removeWhere((j) => j.bodyB == target.body);
    }
    
    target.removeFromParent();
    
    // TUTORIAL PROGRESSION
    if (isTutorial) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        tutorialStepNotifier.value = TutorialStep.explainChronos;
      });
    }

    // Clean up any orphans
    _checkFailCondition();
  }

  void clearLevelState() {
    _boltJoints.clear();
    _boltToHole.clear();
    _holes.clear();
  }

  // --- Component Management (Used by LevelManager) ---

  void addHole(HoleComponent hole) {
    _holes.add(hole);
  }

  void addBoltToLevel(BoltComponent bolt, HoleComponent hole) {
    _boltToHole[bolt] = hole;
  }

  BoltComponent? getBoltAtHole(HoleComponent hole) {
    for (final entry in _boltToHole.entries) {
      if (entry.value == hole) return entry.key;
    }
    return null;
  }

  // --- Physics & Gameplay Logic ---
  void onBoltTapped(BoltComponent bolt) {
    // --- TUTORIAL INTERACTION INTERCEPTION ---
    final step = tutorialStepNotifier.value;
    if (step != null) {
      bool isValidTap = false;

      // PHASE 1: INTERACTIVE RUST INTERCEPTION (Manual tapping 6 times)
      if (step == TutorialStep.explainRust) {
        // Validate tap on the top-left target rusty bolt
        isValidTap = (bolt.body.position.x - (-2.0)).abs() < 0.5;
        if (!isValidTap) {
          bolt.shake();
          return; // Block tapping other items during education
        }
        // ALLOW to fall through to let normal rust physics & deduction execute!
      }

      if (step == TutorialStep.selectTutorialRustBolt || step == TutorialStep.moveTutorialRustBolt) {
        isValidTap = (bolt.body.position.x - (-2.0)).abs() < 0.5 && (bolt.body.position.y - 20.0).abs() < 0.5;
      }

      if (step == TutorialStep.selectLeftBolt || step == TutorialStep.moveLeftBolt) {
        isValidTap = (bolt.body.position.x - (-2.0)).abs() < 0.5;
      } else if (step == TutorialStep.selectRightBolt || step == TutorialStep.moveRightBolt) {
        isValidTap = (bolt.body.position.x - 2.0).abs() < 0.5;
      } else if (step == TutorialStep.selectCenterBolt || step == TutorialStep.moveCenterBolt) {
        isValidTap = (bolt.body.position.x - 0.0).abs() < 0.5;
      }

      if (!isValidTap) {
        bolt.shake();
        return;
      }
    }

    // 1. Handle Rusty Bolts
    if (bolt.isRusty && bolt.hitsRemaining > 1) {
      bolt.hitsRemaining--;
      bolt.shake(); // Visual jiggle
      createSparks(bolt.body.position, isMetalDust: true); // Brown/Grey dust
      audio.playRustTap(); // Gritty rust breaking sound
      
      // DYNAMIC TUTORIAL SINK: Feed current remaining hits directly to the UI overlay!
      if (tutorialStepNotifier.value == TutorialStep.explainRust) {
        rustTutorialHitsNotifier.value = bolt.hitsRemaining;
      }
      return;
    }

    // Clear rust visually once hits are done
    if (bolt.isRusty && bolt.hitsRemaining == 1) {
      bolt.isRusty = false;
      bolt.hitsRemaining = 1; // Standard hits
      createSparks(bolt.body.position); // Final bright spark
      
      // TUTORIAL ADVANCEMENT: Trigger transition to selective moving once rust shatters!
      if (tutorialStepNotifier.value == TutorialStep.explainRust) {
        rustTutorialHitsNotifier.value = 0;
        tutorialStepNotifier.value = TutorialStep.selectTutorialRustBolt;
      }
    }

    if (_activeBolt == bolt) {
      // Toggle off -> Drop back to Static
      _activeBolt?.isLifted = false;
      _activeBolt = null;
      audio.playDropScrew();

      // Tutorial Revert
      if (step == TutorialStep.moveLeftBolt) tutorialStepNotifier.value = TutorialStep.selectLeftBolt;
      if (step == TutorialStep.moveRightBolt) tutorialStepNotifier.value = TutorialStep.selectRightBolt;
      if (step == TutorialStep.moveCenterBolt) tutorialStepNotifier.value = TutorialStep.selectCenterBolt;
      if (step == TutorialStep.moveTutorialRustBolt) tutorialStepNotifier.value = TutorialStep.selectTutorialRustBolt;
    } else {
      // Deselect old if any
      _activeBolt?.isLifted = false;

      // Select New
      _activeBolt = bolt;
      _activeBolt?.isLifted = true;
      audio.playPickScrew();

      // Tutorial Advance
      if (step == TutorialStep.selectLeftBolt) tutorialStepNotifier.value = TutorialStep.moveLeftBolt;
      if (step == TutorialStep.selectRightBolt) tutorialStepNotifier.value = TutorialStep.moveRightBolt;
      if (step == TutorialStep.selectCenterBolt) tutorialStepNotifier.value = TutorialStep.moveCenterBolt;
      if (step == TutorialStep.selectTutorialRustBolt) tutorialStepNotifier.value = TutorialStep.moveTutorialRustBolt;
    }
    updateHoleHighlights();
  }

  void updateHoleHighlights() {
    final active = _activeBolt != null;
    for (final hole in _holes) {
      // A hole is highlightable if:
      // 1. A bolt is selected
      // 2. The hole is not occupied by another bolt
      // 3. The hole is not blocked by a solid plate section
      hole.isTargetHighlight =
          active && !hole.isOccupied && !isHoleBlocked(hole);
    }
  }

  void onHoleTapped(HoleComponent hole) {
    // --- TUTORIAL HOLE INTERCEPTION ---
    final step = tutorialStepNotifier.value;
    if (step != null) {
      bool isValidTarget = false;
      if (step == TutorialStep.moveLeftBolt) {
        isValidTarget = (hole.position.x - (-1.0)).abs() < 0.5 && (hole.position.y - 21.5).abs() < 0.5;
      } else if (step == TutorialStep.moveRightBolt) {
        isValidTarget = (hole.position.x - 1.0).abs() < 0.5 && (hole.position.y - 21.5).abs() < 0.5;
      } else if (step == TutorialStep.moveCenterBolt) {
        final isLeftVacant = (hole.position.x - (-2.0)).abs() < 0.5 && (hole.position.y - 18.0).abs() < 0.5;
        final isRightVacant = (hole.position.x - 2.0).abs() < 0.5 && (hole.position.y - 18.0).abs() < 0.5;
        isValidTarget = isLeftVacant || isRightVacant;
      } else if (step == TutorialStep.moveTutorialRustBolt) {
        isValidTarget = (hole.position.x - (-2.0)).abs() < 0.5 && (hole.position.y - 18.0).abs() < 0.5;
      }

      if (!isValidTarget) {
        _activeBolt?.shake(); // Play feedback on selected bolt that they clicked wrong target
        hole.flashError(); // Squeeze bounce & red flash glow
        return;
      }
    }

    if (hole.isAdLocked) {
      pendingAdHole = hole;
      overlays.add('AdConfirmation');
      return;
    }

    if (_activeBolt == null) return;

    if (hole.isOccupied) {
      _activeBolt?.shake(); // Shake active bolt
      hole.flashError(); // Squeeze bounce & red flash glow
      audio.playBoltTap();
      return;
    }

    // 2. Check for plate occlusion (plate covering hole) using the unified logic
    if (isHoleBlocked(hole)) {
      // Find the specific plate that's blocking for visual feedback
      for (final plate in world.children.whereType<PlateComponent>()) {
        if (plate.isOverlappingCircle(hole.position, hole.radius) &&
            !plate.isHoleAligned(hole.position, tolerance: 0.08)) {
          plate.flashError();
          break;
        }
      }
      _activeBolt?.shake(); // Shake active bolt
      hole.flashError(); // Squeeze bounce & red flash glow
      audio.playBoltTap();
      return;
    } else {
      // Success: Move to clean hole
      _moveBoltToHole(_activeBolt!, hole);
      _activeBolt = null;
      updateHoleHighlights();
    }
  }

  void _moveBoltToHole(BoltComponent bolt, HoleComponent hole) {
    // 1. Capture the source hole of the CURRENT move
    final sourceHole = _boltToHole[bolt];
    if (sourceHole == null) return;

    // 2. Update hole occupancy state immediately
    sourceHole.isOccupied = false;
    hole.isOccupied = true;
    _boltToHole[bolt] = hole;

    // COMBO BOOST: Moving bolts quickly now builds the active Combo Chain!
    _comboCount++;
    _lastMoveTime = 0.0;

    // 3. CREATE GHOST BODY & GHOST JOINTS AT SOURCE HOLE TO KEEP IT PHYSICALLY LOCKED
    final ghostBodyDef = BodyDef(
      position: sourceHole.position,
      type: BodyType.static,
    );
    final ghostBody = world.createBody(ghostBodyDef);
    final ghostJoints = <RevoluteJoint>[];

    final activeJoints = _boltJoints[bolt];
    if (activeJoints != null) {
      for (final joint in List<RevoluteJoint>.from(activeJoints)) {
        final otherBody = joint.bodyB;
        world.destroyJoint(joint);

        final ghostJointDef = RevoluteJointDef()
          ..initialize(ghostBody, otherBody, sourceHole.position)
          ..collideConnected = false;
        final ghostJoint = RevoluteJoint(ghostJointDef);
        world.createJoint(ghostJoint);
        ghostJoints.add(ghostJoint);
      }
      _boltJoints.remove(bolt);
    }

    // 4. TELEPORT ORIGINAL BOLT TO DESTINATION HOLE IMMEDIATELY
    final targetPos = hole.position;
    bolt.body.setTransform(targetPos, bolt.body.angle);
    bolt.body.setType(BodyType.static);

    // 5. CREATE NEW JOINTS AT DESTINATION HOLE IMMEDIATELY (LOCKS DESTINATION INSTANTLY)
    for (final plate in world.children.whereType<PlateComponent>()) {
      final localPoint = plate.body.localPoint(targetPos);
      if (plate.containsLocalPoint(localPoint)) {
        if (plate.isHoleAligned(targetPos, tolerance: 0.12)) {
          createJoint(bolt, plate);
        }
      }
    }

    // 6. ANIMATE VISUAL FLIGHT FROM SOURCE TO DESTINATION
    bolt.moveTo(
      targetPos,
      sourceHole.position,
      onComplete: () {
        // A. DESTROY GHOST AT SOURCE TO FINALLY RELEASE THE SOURCE PHYSICS
        final affectedPlates = <PlateComponent>{};
        for (final joint in ghostJoints) {
          final otherBody = joint.bodyB;
          if (otherBody.userData is PlateComponent) {
            final plate = otherBody.userData as PlateComponent;
            affectedPlates.add(plate);
            plate.showSparks(sourceHole.position);
          }
          world.destroyJoint(joint);
        }
        world.destroyBody(ghostBody);

        // B. RE-EVALUATE GRAVITY FOR AFFECTED PLATES AT SOURCE
        for (final plate in affectedPlates) {
          _updatePlateGravity(plate);
        }

        // C. PLAY AUDIO AND PARTICLES
        audio.playDropScrew();
        createSparks(hole.position);

        // D. UPDATE MOVE HISTORY
        bolt.previousHole = sourceHole;
        _lastMoveTime = 0;
        bolt.isLifted = false;

        // --- TUTORIAL STATE MACHINE PROGRESSION ---
        final currentStep = tutorialStepNotifier.value;
        if (currentStep == TutorialStep.moveLeftBolt) {
          tutorialStepNotifier.value = TutorialStep.selectRightBolt;
        } else if (currentStep == TutorialStep.moveRightBolt) {
          tutorialStepNotifier.value = TutorialStep.explainSwing;
        } else if (currentStep == TutorialStep.moveTutorialRustBolt) {
          tutorialStepNotifier.value = TutorialStep.introBoosters;
        } else if (currentStep == TutorialStep.moveCenterBolt) {
          tutorialStepNotifier.value = null;
          overlays.remove('Tutorial');
        }

        // E. Fail Check - Is the game deadlocked?
        _checkFailCondition();
      },
    );
    hole.playSnapSound();
  }

  void _checkFailCondition() {
    final plates = world.children.whereType<PlateComponent>();
    if (plates.isEmpty) return;

    final unoccupiedHoles = _holes.where((h) => !h.isOccupied);
    if (unoccupiedHoles.isEmpty) {
      // NOTE: Automatic popup disabled as per user request
      // overlays.add('GameOverMenu');
      return;
    }

    final allBlocked = unoccupiedHoles.every((h) => isHoleBlocked(h));
    if (allBlocked && !overlays.isActive('GameOverMenu')) {
      // NOTE: Automatic popup disabled as per user request
      // overlays.add('GameOverMenu');
    }
  }

  // --- Joint count helper for smart gravity management ---
  int _plateJointCount(PlateComponent plate) {
    int count = 0;
    for (final list in _boltJoints.values) {
      for (final j in list) {
        if (j.bodyB == plate.body) count++;
      }
    }
    return count;
  }

  /// 0 joints  → free fall (gravity=1, damping=3)
  /// 1 joint   → pendulum swing (gravity=1, damping=5)
  /// 2+ joints → over-constrained, freeze to kill jitter (gravity=0, damping=20)
  void _updatePlateGravity(PlateComponent plate) {
    final count = _plateJointCount(plate);

    // Ensure continuous collision detection to prevent fast moving plates from going through bolts
    plate.body.isBullet = true;

    if (count >= 2) {
      // Fully pinned: frozen via velocity override to kill any constraint jitter
      plate.body.gravityScale = Vector2.zero();
      plate.body.linearVelocity = Vector2.zero();
      plate.body.angularVelocity = 0;
      plate.body.linearDamping = 20.0;
      plate.body.angularDamping = 20.0;
      plate.setHardPinned(true);
      plate.setCollisionEnabled(true); // Visible physical presence
    } else if (count == 1) {
      // Single joint (pendulum): ALLOW gravity, ALLOW collision
      plate.body.gravityScale = Vector2.all(1.0);
      plate.body.linearDamping =
          0.3; // VERY Low to allow highly agile natural swinging
      plate.body.angularDamping = 0.3;
      plate.setHardPinned(false);
      plate.setCollisionEnabled(true); // COLLISION ON: So it hits other bolts!
      plate.body.setAwake(true);

      // SYMMETRY BREAKER: Kicks plates out of unstable vertical balance (standing up)
      // Uses random side direction to introduce initial non-zero torque instantly
      final double direction = math.Random().nextBool() ? 1.0 : -1.0;
      final double nudgeForce = direction * (plate.body.mass * 4.0);
      plate.body.applyAngularImpulse(nudgeForce);
    } else {
      // Free fall: Max gravity, near-zero damping for explosive terminal velocity
      plate.body.gravityScale = Vector2.all(1.0);
      plate.body.linearDamping =
          0.02; // Almost zero air resistance for max speed
      plate.body.angularDamping = 0.1;
      plate.setHardPinned(false);
      plate.setCollisionEnabled(true); // COLLISION ON: For realistic impacts

      // Soft initial push to encourage direction without snapping unrealistically fast
      plate.body.applyLinearImpulse(Vector2(0, plate.body.mass * 2.0));
      plate.body.setAwake(true);
    }
  }

  void _releaseBolt(BoltComponent bolt, {bool withNudge = true}) {
    final joints = _boltJoints[bolt];
    if (joints != null) {
      final jointsToRemove = List<RevoluteJoint>.from(joints);
      final affectedPlates = <PlateComponent>{};

      for (final joint in jointsToRemove) {
        final otherBody = joint.bodyB;
        if (otherBody.userData is PlateComponent) {
          final plate = otherBody.userData as PlateComponent;
          affectedPlates.add(plate);
          plate.showSparks(bolt.body.position);
        }
        world.destroyJoint(joint);
      }
      _boltJoints.remove(bolt);

      // Re-evaluate gravity for each affected plate based on remaining joint count
      for (final plate in affectedPlates) {
        _updatePlateGravity(plate);
      }
    }
  }

  void createJoint(BoltComponent bolt, PlateComponent plate) {
    // 1. Prevent duplicate joints
    final existingJoints = _boltJoints[bolt];
    if (existingJoints != null) {
      for (final joint in existingJoints) {
        if (joint.bodyB == plate.body) return;
      }
    }

    // 2. Ensure the plate visually has a hole at this attachment point (Safety measure)
    plate.addHole(bolt.body.position);

    // 3. PERFECT ANCHORING: Find the exact center of the hole we are snapping to
    Vector2 anchor = bolt.body.position;
    try {
      final localHoles = plate.localHoles;
      if (localHoles.isNotEmpty) {
        final localBoltPos = plate.body.localPoint(bolt.body.position);
        // Find the hole closest to the bolt's current position
        Vector2 bestHole = localHoles.first;
        double minDist = (bestHole - localBoltPos).length;

        for (final hole in localHoles) {
          final dist = (hole - localBoltPos).length;
          if (dist < minDist) {
            minDist = dist;
            bestHole = hole;
          }
        }

        // If we found a hole within reasonable distance, snap the plate body so the hole centers align perfectly!
        // This eliminates any initial overlap/penetration and guarantees 0% physics jitter.
        // BUT ONLY IF the plate is free (0 active joints) to prevent violating other joint constraints!
        if (minDist < 0.8) {
          final currentWorldHolePos = plate.body.worldPoint(bestHole);
          if (_plateJointCount(plate) == 0) {
            final alignmentOffset = anchor - currentWorldHolePos;
            plate.body.setTransform(plate.body.position + alignmentOffset, plate.body.angle);
            anchor = plate.body.worldPoint(bestHole);
          } else {
            // Already held by other joints, anchor precisely at the bolt's center
            // to prevent shifting the plate and violating existing joints!
            anchor = bolt.body.position;
          }
        }
      }
    } catch (e) {
      // Fallback to bolt position if anything fails
    }

    final jointDef = RevoluteJointDef()
      ..initialize(bolt.body, plate.body, anchor)
      ..collideConnected = false;

    final joint = RevoluteJoint(jointDef);
    world.createJoint(joint);
    _boltJoints.putIfAbsent(bolt, () => []).add(joint);

    // Update gravity based on how many joints this plate now has
    _updatePlateGravity(plate);
  }

  void createSparks(
    Vector2 position, {
    bool isMetalDust = false,
    bool isRustDust = false,
    bool isLightning = false,
  }) {
    final Color color1 = isLightning
        ? Colors.white
        : (isRustDust
              ? const Color(0xFFD35400) // Rust Orange
              : (isMetalDust
                    ? const Color(0xFFBDC3C7)
                    : const Color(0xFFFFD700))); // Steel or Gold

    final Color color2 = isLightning
        ? const Color(0xFF00E5FF) // Vivid Cyan
        : (isRustDust
              ? const Color(0xFF3E2723) // Rust Brown
              : (isMetalDust
                    ? const Color(0xFF7F8C8D)
                    : const Color(0xFFFF4500))); // Dark Steel or Red

    final int count = isLightning
        ? 24 // Massive explosion for lightning
        : ((isMetalDust || isRustDust) ? 4 : 8);

    world.add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: count,
          lifespan: 0.4,
          generator: (i) {
            final cachePaint = Paint();

            return AcceleratedParticle(
              acceleration: Vector2(0, 40), // Tuned for world physics
              speed: Vector2(
                (math.Random().nextDouble() - 0.5) *
                    (isMetalDust || isRustDust
                        ? 15
                        : 30), // Scaled down for world meters
                (math.Random().nextDouble() - 0.5) *
                    (isMetalDust || isRustDust ? 15 : 30),
              ),
              position: position.clone(),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  canvas.drawCircle(
                    Offset.zero,
                    (1 - particle.progress) *
                        0.12, // Properly scaled small world spark
                    cachePaint
                      ..color = Color.lerp(color1, color2, particle.progress)!,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void showComboEffect(Vector2 position, int count) {
    if (count < 1) return;

    // SOUND FIX: Never play heavy non-pooled 'victory' sound during regular gameplay loops
    // Reusing fast, pooled click/booster sounds instead to prevent Android main-thread memory locking
    audio.playBoosterClick();

    // HAPTICS DISABLED FOR DIAGNOSTICS
    /*
    if (count == 1) {
      // HapticFeedback.lightImpact();
    } else if (count == 2) {
      // HapticFeedback.mediumImpact();
    } else if (count == 3) {
      // HapticFeedback.heavyImpact();
    } else {
      // HapticFeedback.vibrate(); 
    }
    */

    String comboText;
    Color glowColor;
    double sizeMultiplier;

    if (count == 1) {
      comboText = 'NICE!';
      glowColor = const Color(0xFFFFD600); // Yellow
      sizeMultiplier = 2;
    } else if (count == 2) {
      comboText = 'FAST!\nCOMBO x2';
      glowColor = const Color(0xFFFFAB00); // Orange Yellow
      sizeMultiplier = 2;
    } else if (count == 3) {
      comboText = 'SUPER!\nCOMBO x3';
      glowColor = const Color(0xFFFF6D00); // Deep Orange
      sizeMultiplier = 2;
    } else {
      comboText = 'JACKPOT!\nCOMBO x$count';
      glowColor = const Color(0xFFFFD700); // Brilliant Gold
      sizeMultiplier = 2;
    }

    final fontSize = 16.0;

    final text = ComboTextComponent(
      text: comboText,
      position: position.clone()..y -= 1.5,
      anchor: Anchor.center,
      priority: 1000,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          fontFamily: 'Courier',
          height: 1.2,
          shadows: [
            Shadow(color: glowColor, blurRadius: 10 * sizeMultiplier),
            Shadow(color: glowColor, blurRadius: 20 * sizeMultiplier),
            const Shadow(
              color: Colors.black,
              offset: Offset(2, 4),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    )..scale = Vector2.all(0.005); // Start super tiny for the pop effect

    world.add(text);

    // Addictive casino pop/bounce animation
    text.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(0.012 * sizeMultiplier), // Explode past normal size
          EffectController(duration: 0.25, curve: Curves.easeOutBack),
        ),
        ScaleEffect.to(
          Vector2.all(0.01 * sizeMultiplier), // Settle down
          EffectController(duration: 0.15, curve: Curves.bounceOut),
        ),
      ]),
    );

    // Float up slowly and fade out smoothly
    text.add(
      MoveByEffect(
        Vector2(0, -3),
        EffectController(duration: 1.2, curve: Curves.easeOutCubic),
      ),
    );

    text.add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.8, startDelay: 0.5),
        onComplete: () => text.removeFromParent(),
      ),
    );
  }

  /// Visually display floating GREEN TEXT indicating the specific amount of SECONDS added to clock.
  void showTimeBonusEffect(Vector2 position, double seconds) {
    final bonusText = '+${seconds.toInt()}s';
    
    final text = ComboTextComponent(
      text: bonusText,
      position: position.clone()..y -= 3.5, // Float much higher to avoid covering plate/combo
      anchor: Anchor.center,
      priority: 1001, 
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontFamily: 'Courier',
          shadows: [
            Shadow(color: Color(0xFF00C853), blurRadius: 12), 
            Shadow(color: Color(0xFF00C853), blurRadius: 20),
            Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4),
          ],
        ),
      ),
    )..scale = Vector2.all(0.005);

    world.add(text);

    text.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(0.018), EffectController(duration: 0.2, curve: Curves.easeOutBack)),
        ScaleEffect.to(Vector2.all(0.015), EffectController(duration: 0.15, curve: Curves.bounceOut)),
      ]),
    );

    text.add(MoveByEffect(Vector2(0, -5), EffectController(duration: 1.5, curve: Curves.easeOutCubic)));
    text.add(OpacityEffect.fadeOut(EffectController(duration: 0.6, startDelay: 0.8), onComplete: () => text.removeFromParent()));
  }

  /// ULTIMATE DESTRUCTION: Cinematic explosion effect for the SMASH booster.
  void showSmashEffect(Vector2 position) {
    // 1. MASSIVE PARTICLE BURST
    createSparks(position, isLightning: true); // Multi-color sparks
    createSparks(position, isMetalDust: true); // Metal debris

    // 2. EXPLOSIVE GHOST CIRCLE (Shockwave)
    final shockwave = CircleComponent(
      radius: 0.1,
      position: position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.white.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 0.2,
    );
    world.add(shockwave);
    shockwave.add(ScaleEffect.to(Vector2.all(40.0), EffectController(duration: 0.4, curve: Curves.easeOutExpo)));
    shockwave.add(OpacityEffect.fadeOut(EffectController(duration: 0.4), onComplete: () => shockwave.removeFromParent()));

    // 3. CINEMATIC "SMASH!" TEXT POP
    final text = ComboTextComponent(
      text: 'SMASH!',
      position: position.clone(),
      anchor: Anchor.center,
      priority: 2000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32.0,
          fontWeight: FontWeight.w900,
          fontFamily: 'Courier',
          fontStyle: FontStyle.italic,
          shadows: [
            Shadow(color: Color(0xFFFF3D00), blurRadius: 20),
            Shadow(color: Color(0xFFFF9100), blurRadius: 40),
            Shadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 10),
          ],
        ),
      ),
    )..scale = Vector2.all(0.001);

    world.add(text);

    // Violent explosive scaling
    text.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(0.04), EffectController(duration: 0.15, curve: Curves.easeOutExpo)),
        ScaleEffect.to(Vector2.all(0.03), EffectController(duration: 0.1, curve: Curves.bounceOut)),
      ]),
    );

    // Fade and lift
    text.add(MoveByEffect(Vector2(0, -4), EffectController(duration: 1.0, curve: Curves.easeOutCubic)));
    text.add(OpacityEffect.fadeOut(EffectController(duration: 0.4, startDelay: 0.6), onComplete: () => text.removeFromParent()));
  }
}

// Custom Text Component to support OpacityEffect
class ComboTextComponent extends TextComponent with HasPaint {
  ComboTextComponent({
    super.text,
    super.position,
    super.anchor,
    super.priority,
    super.textRenderer,
  });

  @override
  void render(Canvas canvas) {
    // Force the text renderer to use the component's opacity
    final currentOpacity = paint.color.opacity;
    if (textRenderer is TextPaint) {
      final tp = textRenderer as TextPaint;
      final style = tp.style;
      textRenderer = TextPaint(
        style: style.copyWith(color: style.color?.withOpacity(currentOpacity)),
      );
    }
    super.render(canvas);
  }
}

class LightningFlashComponent extends PositionComponent with HasGameRef {
  LightningFlashComponent() : super(priority: 9999);

  double _timer = 0;
  final double duration = 0.8;
  final Paint _paint = Paint()..color = Colors.white;

  @override
  void onMount() {
    super.onMount();
    // Cover full viewport strictly
    size = Vector2(10000, 10000);
    position = Vector2(-5000, -5000);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = _timer / duration;
    // Lightning style erratic flicker curve
    double intensity = 0.0;
    if (progress < 0.1) {
      intensity = progress * 10.0; // Rise fast
    } else if (progress < 0.3) {
      intensity = 1.0 - ((progress - 0.1) * 5.0); // Dip fast
    } else if (progress < 0.4) {
      intensity = (progress - 0.3) * 10.0; // Restrike!
    } else {
      intensity = 1.0 - ((progress - 0.4) / 0.6); // Smooth fadeout
    }

    // Mix white and vivid lightning blue
    final color = Color.lerp(
      const Color(0xFF00E5FF).withOpacity(0.7),
      Colors.white,
      0.5 + (0.5 * intensity),
    )!.withOpacity(intensity.clamp(0.0, 1.0));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paint..color = color);
  }
}

class LightningStrikeComponent extends PositionComponent with HasGameRef {
  final Vector2 startPos;
  final Vector2 endPos;
  late final List<Vector2> _segments;

  LightningStrikeComponent({required this.startPos, required this.endPos})
    : super(priority: 9998);

  double _timer = 0;
  final double duration = 0.4;
  late final Paint _boltPaint;
  late final Paint _glowPaint;

  @override
  void onMount() {
    super.onMount();
    _boltPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.6)
      ..strokeWidth = 0.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2);

    // Generate the jagged path immediately
    _generatePath();
  }

  void _generatePath() {
    _segments = [startPos];
    final direction = endPos - startPos;
    final distance = direction.length;
    final normalized = direction.normalized();
    final perpendicular = Vector2(-normalized.y, normalized.x);

    const int stepCount = 8;
    final stepDistance = distance / stepCount;
    final rnd = math.Random();

    for (int i = 1; i < stepCount; i++) {
      final basePos = startPos + (normalized * (stepDistance * i));
      // Max offset scales by distance to avoid tiny strike getting crazy jagged
      final maxOffset = 0.8 * (1 - (i - stepCount / 2).abs() / (stepCount / 2));
      final offsetMagnitude = (rnd.nextDouble() - 0.5) * 2.0 * maxOffset;
      final point = basePos + (perpendicular * offsetMagnitude);
      _segments.add(point);
    }
    _segments.add(endPos);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = _timer / duration;
    // Flicker look
    if ((_timer * 20).toInt() % 2 == 0 && progress < 0.5) {
      // Random brief invisibility frame simulating plasma cooling
      return;
    }

    final fadeOut = (1.0 - progress).clamp(0.0, 1.0);

    final path = Path();
    path.moveTo(_segments.first.x, _segments.first.y);
    for (int i = 1; i < _segments.length; i++) {
      path.lineTo(_segments[i].x, _segments[i].y);
    }

    canvas.drawPath(
      path,
      _glowPaint..color = const Color(0xFF00E5FF).withOpacity(0.6 * fadeOut),
    );
    canvas.drawPath(
      path,
      _boltPaint..color = Colors.white.withOpacity(fadeOut),
    );
  }
}
