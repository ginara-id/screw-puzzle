import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flame/effects.dart';
import '../components/bolt_component.dart';
import '../components/plate_component.dart';
import '../components/hole_component.dart';
import '../components/background_component.dart';

import '../components/industrial_transition.dart';
import '../components/level_clear_effect.dart';
import '../utils/level_manager.dart';

class ScrewPuzzleGame extends Forge2DGame {
  late final LevelManager levelManager;
  int currentLevel = 1;

  // Collision Categories
  static const int kPlateCategory = 0x0001;
  static const int kBoltHoleCategory = 0x0002;

  // Interaction State
  BoltComponent? _activeBolt;

  final _boltJoints = <BoltComponent, List<RevoluteJoint>>{};
  final _boltToHole = <BoltComponent, HoleComponent>{};
  final _holes = <HoleComponent>[];

  ScrewPuzzleGame() : super(gravity: Vector2(0, 30));

  @override
  int get velocityIterations => 12;

  @override
  int get positionIterations => 12;

  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 0. Static Background
    await add(BackgroundComponent());

    camera.viewfinder
      ..zoom = 35.0
      ..position = Vector2(0, 21);

    levelManager = LevelManager(this);

    // Initial Level Load without transition
    await levelManager.loadLevel(currentLevel, transitionMode: TransitionMode.none);

    // Show Main Menu initially
    overlays.add('MainMenu');
  }

  bool _isVictoryTriggered = false;

  @override
  void update(double dt) {
    super.update(dt);
    
    // A level is won if all plates have fallen off the screen
    final plates = world.children.whereType<PlateComponent>();
    
    // If there are no plates, or all plates are off-screen
    if (plates.isEmpty && !_isVictoryTriggered && !overlays.isActive('LevelMap')) {
       _triggerVictorySequence();
       return;
    }

    final viewportHeight = camera.viewport.size.y / camera.viewfinder.zoom;
    final bottomEdge = camera.viewfinder.position.y + (viewportHeight / 2) + 2;
    
    final allOffScreen = plates.every((p) => p.body.position.y > bottomEdge);

    if (allOffScreen && !_isVictoryTriggered && !overlays.isActive('LevelMap')) {
      _triggerVictorySequence();
    }
  }

  void _triggerVictorySequence() {
     if (_isVictoryTriggered || overlays.isActive('WinMenu')) return;
     _isVictoryTriggered = true;
     
     // Spawn the level clear effect (sparks/shockwave) behind the doors
     add(LevelClearEffect());
     
     // Close the heavy industrial doors, then show the win menu!
     camera.viewport.add(IndustrialTransitionComponent(
       mode: TransitionMode.closeOnly,
       onHalfway: () async {
         if (!overlays.isActive('WinMenu')) {
           overlays.add('WinMenu');
         }
       },
     ));
  }

  void showSteamTransition(Future<void> Function() onHalfway, {TransitionMode mode = TransitionMode.closeAndOpen}) {
    camera.viewport.children.whereType<IndustrialTransitionComponent>().forEach((c) => c.removeFromParent());
    camera.viewport.add(IndustrialTransitionComponent(onHalfway: onHalfway, mode: mode));
  }

  // --- Level Flow ---

  void nextLevel() {
    _isVictoryTriggered = false;
    currentLevel++;
    levelManager.loadLevel(currentLevel, transitionMode: TransitionMode.openOnly);
  }

  void resetLevel() {
    _isVictoryTriggered = false;
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
    _updateHoleHighlights();
  }

  void _updateHoleHighlights() {
    final active = _activeBolt != null;
    for (final hole in _holes) {
      hole.isTargetHighlight = active && !hole.isOccupied;
    }
  }

  void onHoleTapped(HoleComponent hole) {
    if (_activeBolt == null) return;

    // 1. Check for physical occupancy (bolt in hole)
    if (hole.isOccupied) {
      _activeBolt?.shake();
      return;
    }

    // 2. Check for plate occlusion (plate covering hole)
    PlateComponent? blocker;
    for (final plate in world.children.whereType<PlateComponent>()) {
      final localPoint = plate.body.localPoint(hole.position);
      if (plate.containsLocalPoint(localPoint)) {
        blocker = plate;
        break;
      }
    }

    if (blocker != null) {
      // 3. Alignment Exception: Can we bolt THROUGH this plate?
      if (blocker.isHoleAligned(hole.position)) {
        blocker = null; // Path is clear through the plate's own hole!
      }
    }

    if (blocker != null) {
      // Feedback: Plate is genuinely in the way (solid wood)
      blocker.flashError();
      _activeBolt?.shake();
    } else {
      // Success: Move to clean hole (or through an aligned plate hole)
      _moveBoltToHole(_activeBolt!, hole);
      _activeBolt = null;
      _updateHoleHighlights();
    }
  }

  void _moveBoltToHole(BoltComponent bolt, HoleComponent hole) {
    // STATE: MOVEMENT START - Now we physically detach
    _releaseBolt(bolt);

    _boltToHole[bolt]?.isOccupied = false;
    hole.isOccupied = true;
    _boltToHole[bolt] = hole;

    bolt.moveTo(
      hole.position,
      onComplete: () {
        // STATE: SNAPPING & RE-LOCKING
        final targetPos = hole.position;

        // 100% Precise positioning
        bolt.body.setTransform(targetPos, 0);
        bolt.body.setType(BodyType.static);

        // Global scan for ALL plates that should now be attached
        for (final plate in world.children.whereType<PlateComponent>()) {
          final localPoint = plate.body.localPoint(targetPos);
          if (plate.containsLocalPoint(localPoint)) {
            createJoint(bolt, plate);
          }
        }
        bolt.isLifted = false;

        // STATE: Fail Check - Is the game deadlocked?
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

    // A hole is "blocked" if ANY plate covers it
    bool isBlocked(HoleComponent hole) {
      for (final plate in plates) {
        final localPoint = plate.body.localPoint(hole.position);
        if (plate.containsLocalPoint(localPoint)) return true;
      }
      return false;
    }

    final allBlocked = unoccupiedHoles.every(isBlocked);
    if (allBlocked && !overlays.isActive('GameOverMenu')) {
      // NOTE: Automatic popup disabled as per user request
      // overlays.add('GameOverMenu');
    }
  }

  void _releaseBolt(BoltComponent bolt) {
    final joints = _boltJoints.remove(bolt);
    if (joints != null) {
      for (final joint in joints) {
        // Trigger metallic sparks at the detachment point
        final plate = joint.bodyB.userData;
        if (plate is PlateComponent) {
          plate.showSparks(bolt.body.position);
          plate.body.setAwake(true);
        }
        world.destroyJoint(joint);
      }
    }
  }

  void createJoint(BoltComponent bolt, PlateComponent plate) {
    final jointDef = RevoluteJointDef()
      ..initialize(bolt.body, plate.body, bolt.body.position)
      ..collideConnected = false;

    final joint = RevoluteJoint(jointDef);
    world.createJoint(joint);

    // Add to multi-joint collection
    _boltJoints.putIfAbsent(bolt, () => []).add(joint);
  }
}
