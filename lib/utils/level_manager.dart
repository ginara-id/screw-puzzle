import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../game/screw_game.dart';
import '../components/bolt_component.dart';
import '../components/plate_component.dart';
import '../components/hole_component.dart';

import '../components/industrial_transition.dart';

class LevelManager {
  final ScrewPuzzleGame game;

  LevelManager(this.game);

  Future<void> loadLevel(
    int levelNumber, {
    TransitionMode transitionMode = TransitionMode.closeAndOpen,
  }) async {
    final String path = 'assets/levels/level_$levelNumber.json';
    String content = '';
    try {
      content = await rootBundle.loadString(path);
    } catch (e) {
      print('Error loading level file: $e');
      // If file missing, just return to menu or show error
      game.overlays.add('MainMenu');
      return;
    }

    final dynamic data = jsonDecode(content);

    game.showSteamTransition(
      () async {
      try {
        // 1. Clear previous world data
        game.world.removeAll(game.world.children);
        game.clearLevelState();

        // 1.5 Load Level-Specific Time Limit (Fallback to 120s if not present in JSON)
        final num timeFromData = data['timeLimit'] ?? 120.0;
        game.setLevelTimeLimit(timeFromData.toDouble());

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
            isAdLocked: holeData['isAdLocked'] as bool? ?? false,
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
          final bolt = BoltComponent(
            initialPosition: pos,
            isRusty: boltData['isRusty'] as bool? ?? false,
          );

          final hole = allHoles.firstWhere(
            (h) => h.initialPosition.distanceTo(pos) < 0.1,
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

          final localHolesData = pDataMap['holes'] as List;

          // Calculate minimum size required to contain all holes safely
          double maxAbsX = 0;
          double maxAbsY = 0;
          for (final Map<String, dynamic> lHoleData
              in localHolesData.cast<Map<String, dynamic>>()) {
            final lx = (lHoleData['x'] as num).toDouble().abs();
            final ly = (lHoleData['y'] as num).toDouble().abs();
            if (lx > maxAbsX) maxAbsX = lx;
            if (ly > maxAbsY) maxAbsY = ly;
          }

          // Hole radius is 0.35.
          // endPadding: gap from hole edge to the 'tips' of the plate.
          // sidePadding: gap from hole edge to the 'sides' (thickness) of the plate.
          const holeRadius = 0.35;
          const endPadding = 0.18;
          const sidePadding = 0.12;

          double minWidth, minHeight;
          if (maxAbsX == 0 && maxAbsY == 0) {
            // Single central hole or all holes at center: keep it symmetric
            minWidth = (holeRadius + endPadding) * 2;
            minHeight = (holeRadius + endPadding) * 2;
          } else if (maxAbsX >= maxAbsY) {
            // Horizontal or Square-ish: X is the long axis
            minWidth = (maxAbsX + holeRadius + endPadding) * 2;
            minHeight = (maxAbsY + holeRadius + sidePadding) * 2;
          } else {
            // Vertical: Y is the long axis
            minWidth = (maxAbsX + holeRadius + sidePadding) * 2;
            minHeight = (maxAbsY + holeRadius + endPadding) * 2;
          }

          final scaledWidth = (pDataMap['width'] as num).toDouble() * 0.70;
          final scaledHeight = (pDataMap['height'] as num).toDouble() * 0.70;

          double finalWidth = scaledWidth.clamp(minWidth, double.infinity);
          double finalHeight = scaledHeight.clamp(minHeight, double.infinity);

          final shapeStr = pDataMap['shape'] as String? ?? (pDataMap['isCircle'] == true ? 'circle' : 'box');
          PlateShape shapeType;
          switch (shapeStr) {
            case 'circle': shapeType = PlateShape.circle; break;
            case 'triangle': shapeType = PlateShape.triangle; break;
            default: shapeType = PlateShape.box;
          }

          // Fix: If it's a circle or triangle, width and height should be equal for symmetry if not specified
          if (shapeType == PlateShape.circle || shapeType == PlateShape.triangle) {
            final side = finalWidth > finalHeight ? finalWidth : finalHeight;
            finalWidth = side;
            finalHeight = side;
          }

          final plate = PlateComponent(
            size: Vector2(finalWidth, finalHeight),
            initialPosition: platePos,
            shapeType: shapeType,
          );

          await game.world.add(plate);

          for (final Map<String, dynamic> lHoleData
              in localHolesData.cast<Map<String, dynamic>>()) {
            final localPos = Vector2(
              (lHoleData['x'] as num).toDouble(),
              (lHoleData['y'] as num).toDouble(),
            );
            final worldPos = platePos + localPos;

            final hole = allHoles.firstWhere(
              (h) => h.initialPosition.distanceTo(worldPos) < 0.1,
              orElse: () => throw Exception('Hole not found at $worldPos'),
            );

            final bolt = game.getBoltAtHole(hole);
            if (bolt != null) {
              game.createJoint(bolt, plate);
            }
            plate.addHole(worldPos);
          }
        }
      } catch (e) {
        print('CRITICAL ERROR LOADING LEVEL: $e');
        // Still allow the transition to finish so doors don't stay closed
      }
    }, mode: transitionMode);
  }
}
