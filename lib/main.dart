import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/screw_game.dart';
import 'utils/overlay_manager.dart';
import 'utils/level_map_overlay.dart';

void main() {
  runApp(
    GameWidget<ScrewPuzzleGame>.controlled(
      gameFactory: ScrewPuzzleGame.new,
      overlayBuilderMap: {
        'MainMenu': (context, game) => MainMenu(game: game),
        'WinMenu': (context, game) => WinMenu(game: game),
        'GameOverMenu': (context, game) => GameOverMenu(game: game),
        'HUD': (context, game) => HUDMenu(game: game),
        'LevelMap': (context, game) => LevelMapOverlay(game: game),
      },
    ),
  );
}
