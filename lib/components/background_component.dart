import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image, Picture; // Hide to avoid conflict
import '../game/screw_game.dart';

class BackgroundComponent extends PositionComponent with HasGameRef<ScrewPuzzleGame> {
  Picture? _cachedPicture;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = gameRef.canvasSize;
    priority = -10;
    _preRender();
  }

  void _preRender() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = size.toRect();

    // 1. DEEP CHARCOAL LINEAR GRADIENT
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0F171E), // Near Black
          const Color(0xFF1C2833), // Deep Charcoal
          const Color(0xFF121212), // Dark Charcoal (No Navy)
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. SIMULATED CARBON FIBER TEXTURE
    final weavePaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final weaveSpacing = 8.0;
    for (double i = -size.y; i < size.x; i += weaveSpacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.y, size.y), weavePaint);
    }
    for (double i = size.x + size.y; i > 0; i -= weaveSpacing) {
      canvas.drawLine(Offset(i, 0), Offset(i - size.y, size.y), weavePaint);
    }

    // 3. VIGNETTE
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.5,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.6),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, vignettePaint);

    _cachedPicture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }
  }

  @override
  void onRemove() {
    _cachedPicture?.dispose();
    super.onRemove();
  }
}
