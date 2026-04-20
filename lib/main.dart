import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/screw_game.dart';
import 'utils/overlay_manager.dart';
import 'utils/dialog_overlay.dart';
import 'utils/story_manager.dart';
import 'utils/level_map_overlay.dart';

void main() {
  runApp(
    GameWidget<ScrewPuzzleGame>.controlled(
      gameFactory: ScrewPuzzleGame.new,
      overlayBuilderMap: {
        'WinMenu': (context, game) => WinMenu(game: game),
        'GameOverMenu': (context, game) => GameOverMenu(game: game),
        'HUD': (context, game) => HUDMenu(game: game),
        'StoryOverlay': (context, game) {
          final beats = StoryManager.getBeatsForLevel(game.currentLevel);
          return DialogOverlay(
            game: game,
            beats: beats,
            onFinish: () {
              game.overlays.remove('StoryOverlay');
              game.resumeEngine();
            },
          );
        },
        'LevelMap': (context, game) => LevelMapOverlay(game: game),
      },
    ),
  );
}
