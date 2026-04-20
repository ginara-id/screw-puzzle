import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../game/screw_game.dart';
import '../components/bolt_component.dart';
import '../components/plate_component.dart';
import '../components/hole_component.dart';
import 'story_manager.dart';

class LevelManager {
  final ScrewPuzzleGame game;

  LevelManager(this.game);

  Future<void> loadLevel(int levelNumber) async {
    final String path = 'assets/levels/level_$levelNumber.json';
    final String content = await rootBundle.loadString(path);
    final dynamic data = jsonDecode(content);

    // 1. Clear previous world data
    game.world.removeAll(game.world.children);
    game.clearLevelState();

    // 2. Spawn Holes
    final holesData = data['holes'] as List;
    final allHoles = <HoleComponent>[];

    for (final Map<String, dynamic> holeData
        in holesData.cast<Map<String, dynamic>>()) {
      final hole = HoleComponent(
        initialPosition: Vector2(
          (holeData['x'] as num).toDouble(),
          (holeData['y'] as num).toDouble(),
        ),
        isOccupied: false,
      );
      game.addHole(hole);
      await game.world.add(hole);
      allHoles.add(hole);
    }

    // 3. Spawn Bolts
    final boltsData = data['bolts'] as List;
    for (final Map<String, dynamic> boltData
        in boltsData.cast<Map<String, dynamic>>()) {
      final pos = Vector2(
        (boltData['x'] as num).toDouble(),
        (boltData['y'] as num).toDouble(),
      );
      final bolt = BoltComponent(initialPosition: pos);

      // Find the hole corresponding to this bolt
      final hole = allHoles.firstWhere(
        (h) => h.position.distanceTo(pos) < 0.1,
        orElse: () => throw Exception('No hole found for bolt at $pos'),
      );

      game.addBoltToLevel(bolt, hole);
      await game.world.add(bolt);
      hole.isOccupied = true;
    }

    // 4. Spawn Plates
    final platesData = data['plates'] as List;
    for (final Map<String, dynamic> pDataMap
        in platesData.cast<Map<String, dynamic>>()) {
      final platePos = Vector2(
        (pDataMap['x'] as num).toDouble(),
        (pDataMap['y'] as num).toDouble(),
      );

      final plate = PlateComponent(
        size: Vector2(
          (pDataMap['width'] as num).toDouble(),
          (pDataMap['height'] as num).toDouble(),
        ),
        initialPosition: platePos,
      );
      // Optional plate coloring logic based on JSON color hex if needed,
      // but right now PlateComponent doesn't consume `color` in constructor.

      await game.world.add(plate);

      // Create joints & initialize local holes in the wood
      final localHolesData = pDataMap['holes'] as List;
      for (final Map<String, dynamic> lHoleData
          in localHolesData.cast<Map<String, dynamic>>()) {
        final localPos = Vector2(
          (lHoleData['x'] as num).toDouble(),
          (lHoleData['y'] as num).toDouble(),
        );
        final worldPos = platePos + localPos;

        final hole = allHoles.firstWhere(
          (h) => h.position.distanceTo(worldPos) < 0.1,
          orElse: () => throw Exception('Hole not found at $worldPos'),
        );

        // 1. Physical Joint
        final bolt = game.getBoltAtHole(hole);
        if (bolt != null) {
          game.createJoint(bolt, plate);
        }

        // 2. Visual Drill Hole (Permanent feature of this wood)
        plate.addHole(hole.position);
      }
    }

    // 5. AAA Polish - Steam Transition
    game.showSteamTransition(() {
       _checkAndShowStory();
    });
  }

  void _checkAndShowStory() {
    final beats = StoryManager.getBeatsForLevel(game.currentLevel);
    if (beats.isNotEmpty) {
      game.pauseEngine();
      game.overlays.add('StoryOverlay');
    }
  }
}
