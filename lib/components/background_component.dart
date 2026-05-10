import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/screw_game.dart';

class BackgroundComponent extends PositionComponent with HasGameRef<ScrewPuzzleGame> {
  bool _isLoaded = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = gameRef.canvasSize;
    priority = -10;
    _isLoaded = true;
  }

  @override
  void render(Canvas canvas) {
    if (!_isLoaded) return;
    final rect = size.toRect();

    // 1. DEEP CHARCOAL LINEAR GRADIENT
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0F171E), // Near Black
          const Color(0xFF1C2833), // Deep Charcoal
          const Color(0xFF151922), // Dark Navy/Charcoal
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. SIMULATED CARBON FIBER TEXTURE (Subtle crosshatch pattern)
    // Since we don't have the image asset loaded yet, we draw a programmatic carbon weave
    final weavePaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final weaveSpacing = 8.0;
    
    // Draw diagonal lines to simulate the weave
    for (double i = -size.y; i < size.x; i += weaveSpacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.y, size.y),
        weavePaint,
      );
    }
    for (double i = size.x + size.y; i > 0; i -= weaveSpacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.y, size.y),
        weavePaint,
      );
    }
    
    // Add subtle shadow vignette around the edges
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
  }
}
