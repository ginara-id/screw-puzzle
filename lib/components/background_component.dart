import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../game/screw_game.dart';

class BackgroundComponent extends PositionComponent
    with HasGameRef<ScrewPuzzleGame> {
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

    // 1. BLURRED FACTORY BACKGROUND (Deep Workshop)
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [const Color(0xFF1A1C1E), const Color(0xFF0A0B0C)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // DRAW BACKGROUND PIPES (Subtle industrial depth)
    final pipePaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0;
    canvas.drawLine(Offset(size.x * 0.2, 0), Offset(size.x * 0.2, size.y), pipePaint);
    canvas.drawLine(Offset(size.x * 0.8, 0), Offset(size.x * 0.8, size.y), pipePaint);
    canvas.drawLine(Offset(0, size.y * 0.85), Offset(size.x, size.y * 0.85), pipePaint..strokeWidth = 35.0);

    // 2. THE MAIN CONSOLE (HEAVY RIVETED BOX)
    const boardWorldWidth = 15.5;
    const boardWorldHeight = 19.5;
    
    final zoom = gameRef.camera.viewfinder.zoom;
    final boardWidth = boardWorldWidth * zoom;
    final boardHeight = boardWorldHeight * zoom;

    final boardRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2.2), // Shifted up slightly
      width: boardWidth,
      height: boardHeight,
    );

    // DEEP SHADOW
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.shift(const Offset(15, 15)), const Radius.circular(5)),
      Paint()..color = Colors.black.withOpacity(0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );

    // BORDER FRAME (Rust Metal)
    final framePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF3E3E3E), const Color(0xFF1E1E1E), const Color(0xFF2D2D2D)],
      ).createShader(boardRect);
    canvas.drawRect(boardRect, framePaint);

    // INNER AREA (Blueprint / Technical with SPOTLIGHT)
    final innerRect = boardRect.deflate(40.0);
    final innerPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.2, // Expanded radius
        colors: [
          const Color(0xFF34495E), // Brighter & Wider
          const Color(0xFF1B242C), 
          const Color(0xFF0F1418),
        ],
        stops: const [0.0, 0.7, 1.0], // Softer falloff
      ).createShader(innerRect);
    canvas.drawRect(innerRect, innerPaint);

    // ADD A SOFT SPOTLIGHT GLOW
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.1), Colors.transparent],
      ).createShader(innerRect);
    canvas.drawRect(innerRect, glowPaint);

    // BLUEPRINT LINES (More visible now)
    final blueprintPaint = Paint()
      ..color = const Color(0xFF4A90E2).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 0.0; i < innerRect.width; i += 60) {
      canvas.drawLine(Offset(innerRect.left + i, innerRect.top), Offset(innerRect.left + i, innerRect.bottom), blueprintPaint);
    }
    for (var i = 0; i < innerRect.height; i += 60) {
      canvas.drawLine(Offset(innerRect.left, innerRect.top + i), Offset(innerRect.right, innerRect.top + i), blueprintPaint);
    }
    canvas.drawCircle(boardRect.center, 150, blueprintPaint..color = blueprintPaint.color.withOpacity(0.03));

    // 3. RIVETS (The iconic industrial look)
    final rivetPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF555555), const Color(0xFF111111)],
      ).createShader(Rect.fromLTWH(0, 0, 15, 15));
    
    void drawRivetsOnSide(Offset start, Offset end, int count) {
      for (var i = 0; i < count; i++) {
        final pos = Offset.lerp(start, end, i / (count - 1))!;
        canvas.drawCircle(pos, 6, rivetPaint);
        canvas.drawCircle(pos, 2, Paint()..color = Colors.black.withOpacity(0.4));
      }
    }

    drawRivetsOnSide(boardRect.topLeft + const Offset(20, 20), boardRect.topRight + const Offset(-20, 20), 12);
    drawRivetsOnSide(boardRect.bottomLeft + const Offset(20, -20), boardRect.bottomRight + const Offset(-20, -20), 12);
    drawRivetsOnSide(boardRect.topLeft + const Offset(20, 20), boardRect.bottomLeft + const Offset(20, -20), 15);
    drawRivetsOnSide(boardRect.topRight + const Offset(-20, 20), boardRect.bottomRight + const Offset(-20, -20), 15);

    // 5. OVERALL VIGNETTE
    canvas.drawRect(rect, Paint()..shader = RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.7)], stops: const [0.4, 1.0]).createShader(rect));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }
}

extension on Offset {
  Offset rotate(double angle) {
    return Offset(
      dx * math.cos(angle) - dy * math.sin(angle),
      dx * math.sin(angle) + dy * math.cos(angle),
    );
  }
}
