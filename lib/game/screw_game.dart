import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;
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

class ScrewPuzzleGame extends Forge2DGame {
  late final LevelManager levelManager;
  final audio = AudioService();
  int currentLevel = 1;

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
        // Strict tolerance for perfect alignment (0.05)
        if (!plate.isHoleAligned(hole.position, tolerance: 0.15)) {
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

  ScrewPuzzleGame()
    : super(
        gravity: Vector2(0, 30.0), // Supercharged gravity for snappy, realistic fall impacts
      ) {
    velocityIterations = 25; // Tighter constraint tolerance
    positionIterations = 25;
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Initialize Audio
    await audio.init();
    audio.playMenuBGM();

    // 0. Static Background
    await add(BackgroundComponent());

    camera.viewfinder
      ..zoom = 35.0
      ..position = Vector2(0, 22.0); // Lifted to accommodate bottom ad

    levelManager = LevelManager(this);

    // PERSISTENCE: Load last played level
    final prefs = await SharedPreferences.getInstance();
    currentLevel = prefs.getInt('current_level') ?? 1;

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
  double _remainingTime = 60.0; // Default 60s
  bool _isGameOver = false;
  bool get isGameOver => _isGameOver;
  double get remainingTime => _remainingTime;

  double _victoryCheckTimer = 0;

  // COMBO SYSTEM
  double _lastMoveTime = 0;
  int _comboCount = 0;
  static const double comboWindow = 1.8; // Faster, more challenging window

  @override
  void update(double dt) {
    super.update(dt);
    _lastMoveTime += dt;

    // Reset combo if idle for too long
    if (_lastMoveTime > comboWindow) {
      _comboCount = 0;
    }

    // Throttle heavy checks to run every 0.1s instead of every frame
    _victoryCheckTimer += dt;
    if (_victoryCheckTimer < 0.1) return;
    _victoryCheckTimer = 0;

    final plates = world.children.whereType<PlateComponent>();
    bool isInGame = overlays.isActive('HUD') && !overlays.isActive('MainMenu');

    if (isInGame && plates.isEmpty && !_isVictoryTriggered) {
      _triggerVictorySequence();
      return;
    }

    // 1. HANDLE TIMER
    if (isInGame && !_isVictoryTriggered && !_isGameOver) {
      _remainingTime -= dt;
      if (_remainingTime <= 0) {
        _remainingTime = 0;
        _triggerGameOver();
      }

      // Pulse feel when low on time
      if (_remainingTime < 10 && _remainingTime > 0) {
        if ((_remainingTime * 4).toInt() % 2 == 0) {
          HapticFeedback.selectionClick();
        }
      }
    }

    final viewportHeight = camera.viewport.size.y / camera.viewfinder.zoom;
    final bottomEdge = camera.viewfinder.position.y + (viewportHeight / 2) + 2;

    // PERFORMANCE: Remove plates that are way off screen to save physics CPU
    for (final plate in plates.toList()) {
      if (plate.body.position.y > bottomEdge + 10) {
        _comboCount++;
        _lastMoveTime = 0.0;
        showComboEffect(plate.body.position, _comboCount);

        // COMBO TIME BONUS: Each combo level adds more time!
        final double timeBonus = 5.0 * _comboCount;
        _remainingTime += timeBonus;

        HapticFeedback.lightImpact(); // Feedback for time gain
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
    if (_isGameOver) return;
    _isGameOver = true;
    // No more flame-based banners, rely on the Flutter UI overlay

    audio.playGameOver();

    // Delay showing the menu a bit to let the banner slam
    Future.delayed(const Duration(seconds: 2), () {
      overlays.add('GameOverMenu');
    });
  }

  // Removed old static showScoreEffect

  void _triggerVictorySequence() {
    if (_isVictoryTriggered || overlays.isActive('WinMenu')) return;
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
            overlays.add('WinMenu');
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
    currentLevel++;

    // PERSISTENCE: Save progress
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_level', currentLevel);

    if (currentLevel > 10) {
      // Game Complete!
      currentLevel = 1;
      await prefs.setInt('current_level', currentLevel);

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

  void resetLevel() {
    _isVictoryTriggered = false;
    _isGameOver = false;
    _remainingTime = 60.0;
    levelManager.loadLevel(currentLevel);
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
    // 1. Handle Rusty Bolts
    if (bolt.isRusty && bolt.hitsRemaining > 1) {
      bolt.hitsRemaining--;
      bolt.shake(); // Visual jiggle
      createSparks(bolt.body.position, isMetalDust: true); // Brown/Grey dust
      audio.playBoltTap(); // We could add a 'scrape' sound later
      HapticFeedback.lightImpact();
      return;
    }

    // Clear rust visually once hits are done
    if (bolt.isRusty && bolt.hitsRemaining == 1) {
      bolt.isRusty = false;
      bolt.hitsRemaining = 1; // Standard hits
      createSparks(bolt.body.position); // Final bright spark
      HapticFeedback.mediumImpact();
    }

    if (_activeBolt == bolt) {
      // Toggle off -> Drop back to Static
      _activeBolt?.isLifted = false;
      _activeBolt = null;
    } else {
      // Deselect old if any
      _activeBolt?.isLifted = false;

      // Select New
      _activeBolt = bolt;
      _activeBolt?.isLifted = true;
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
    if (hole.isAdLocked) {
      pendingAdHole = hole;
      overlays.add('AdConfirmation');
      return;
    }

    if (_activeBolt == null) return;

    if (hole.isOccupied) {
      _activeBolt?.shake();
      return;
    }

    // 2. Check for plate occlusion (plate covering hole) using the unified logic
    if (isHoleBlocked(hole)) {
      // Find the specific plate that's blocking for visual feedback
      for (final plate in world.children.whereType<PlateComponent>()) {
        if (plate.isOverlappingCircle(hole.position, hole.radius) &&
            !plate.isHoleAligned(hole.position, tolerance: 0.05)) {
          plate.flashError();
          break;
        }
      }
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

    // 2. Update hole occupancy state immediately
    _boltToHole[bolt]?.isOccupied = false;
    hole.isOccupied = true;
    _boltToHole[bolt] = hole;

    bolt.moveTo(
      hole.position,
      onComplete: () {
        // 3. Check if this target hole is where the bolt came from in the PREVIOUS move
        final isBackAndForth = bolt.previousHole == hole;

        // Check if the move is meaningful (released or pinned a plate)
        final wasHoldingPlate = _boltJoints[bolt]?.isNotEmpty ?? false;

        _releaseBolt(bolt, withNudge: false);
        audio.playBoltSnap();
        createSparks(hole.position);

        final targetPos = hole.position;
        bolt.body.setTransform(targetPos, 0);
        bolt.body.setType(BodyType.static);

        bool isNowHoldingPlate = false;
        for (final plate in world.children.whereType<PlateComponent>()) {
          final localPoint = plate.body.localPoint(targetPos);
          if (plate.containsLocalPoint(localPoint)) {
            if (plate.isHoleAligned(targetPos)) {
              createJoint(bolt, plate);
              isNowHoldingPlate = true;
            }
          }
        }

        // Only trigger combo if it was a meaningful move AND not returning to previous spot
        if ((wasHoldingPlate || isNowHoldingPlate) && !isBackAndForth) {
          if (_lastMoveTime < comboWindow) {
            _comboCount++;
            showComboEffect(hole.position, _comboCount);
            HapticFeedback.mediumImpact();
          } else {
            _comboCount = 1;
            showComboEffect(hole.position, 1);
            HapticFeedback.lightImpact();
          }
        } else {
          // If the move was NOT meaningful or was back-and-forth, BREAK THE COMBO
          _comboCount = 0;
        }

        // NOW update the history: The source of THIS move is now the "previous" for the NEXT move
        bolt.previousHole = sourceHole;
        _lastMoveTime = 0;
        bolt.isLifted = false;

        // 6. Fail Check - Is the game deadlocked?
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
      plate.body.linearDamping = 1.5;   // Low enough to swing naturally
      plate.body.angularDamping = 1.5;
      plate.setHardPinned(false);
      plate.setCollisionEnabled(true);  // COLLISION ON: So it hits other bolts!
      plate.body.setAwake(true);
    } else {
      // Free fall: Max gravity, near-zero damping for explosive terminal velocity
      plate.body.gravityScale = Vector2.all(1.0);
      plate.body.linearDamping = 0.02;  // Almost zero air resistance for max speed
      plate.body.angularDamping = 0.1;
      plate.setHardPinned(false);
      plate.setCollisionEnabled(true);  // COLLISION ON: For realistic impacts
      
      // Larger initial push down to simulate instant gravity snap
      plate.body.applyLinearImpulse(Vector2(0, plate.body.mass * 8.0));
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

          if (withNudge) {
            final nudge = (math.Random().nextDouble() - 0.5) * 5.0;
            plate.body.applyAngularImpulse(nudge);
          }
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

        // If we found a hole within reasonable distance, snap the anchor to its WORLD center
        if (minDist < 0.8) {
          anchor = plate.body.worldPoint(bestHole);
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
  }) {
    final Color color1 = isRustDust
        ? const Color(0xFFD35400) // Rust Orange
        : (isMetalDust
              ? const Color(0xFFBDC3C7)
              : const Color(0xFFFFD700)); // Steel or Gold

    final Color color2 = isRustDust
        ? const Color(0xFF3E2723) // Rust Brown
        : (isMetalDust
              ? const Color(0xFF7F8C8D)
              : const Color(0xFFFF4500)); // Dark Steel or Red

    final int count = (isMetalDust || isRustDust)
        ? 4
        : 8; // Reduced for performance

    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: count,
          lifespan: 0.4,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, 20),
            speed: Vector2(
              (math.Random().nextDouble() - 0.5) *
                  (isMetalDust || isRustDust ? 300 : 600),
              (math.Random().nextDouble() - 0.5) *
                  (isMetalDust || isRustDust ? 300 : 600),
            ),
            position: position.clone(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final paint = Paint()
                  ..color = Color.lerp(color1, color2, particle.progress)!
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

                canvas.drawCircle(
                  Offset.zero,
                  (1 - particle.progress) * 2.0,
                  paint,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void showComboEffect(Vector2 position, int count) {
    if (count < 1) return;

    // CASINO STYLE: Escalating haptics and sounds
    if (count == 1) {
      audio.playBoosterClick();
      HapticFeedback.lightImpact();
    } else if (count == 2) {
      audio.playVictory();
      HapticFeedback.mediumImpact();
    } else if (count == 3) {
      audio.playVictory();
      HapticFeedback.heavyImpact();
    } else {
      audio.playVictory();
      HapticFeedback.vibrate(); // Maximum intensity
    }

    String comboText;
    Color glowColor;
    double sizeMultiplier;

    if (count == 1) {
      comboText = 'NICE!';
      glowColor = const Color(0xFFFFD600); // Yellow
      sizeMultiplier = 1.8;
    } else if (count == 2) {
      comboText = 'FAST!\nCOMBO x2';
      glowColor = const Color(0xFFFFAB00); // Orange Yellow
      sizeMultiplier = 1.8;
    } else if (count == 3) {
      comboText = 'SUPER!\nCOMBO x3';
      glowColor = const Color(0xFFFF6D00); // Deep Orange
      sizeMultiplier = 1.8;
    } else {
      comboText = 'JACKPOT!\nCOMBO x$count';
      glowColor = const Color(0xFFFFD700); // Brilliant Gold
      sizeMultiplier = 1.8;
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
