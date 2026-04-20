import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class BackgroundComponent extends PositionComponent with HasGameRef {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = gameRef.canvasSize;
    priority = -1; // Ensure background renders behind everything
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();

    // 1. IMPROVED MAHOGANY WOOD TEXTURE
    final woodPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF2D1E12), 
          Color(0xFF4D331F), // Lighter highlight
          Color(0xFF2D1E12),
          Color(0xFF1B120B), // Darker shadow
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, woodPaint);

    // 2. INDUSTRIAL GRAIN & WEAR
    final grainPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.03;

    for (double i = 0; i < size.y; i += 0.15) {
      canvas.drawLine(Offset(0, i), Offset(size.x, i), grainPaint);
    }

    // 3. BRASS CORNER GUARDS
    final brassPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFB8860B), const Color(0xFFFFD700), const Color(0xFFB8860B)],
      ).createShader(Rect.fromLTWH(0, 0, 40, 40));

    // Top-Left Corner
    final cornerPath = Path()
      ..moveTo(0, 0)
      ..lineTo(40, 0)
      ..lineTo(0, 40)
      ..close();
    canvas.drawPath(cornerPath, brassPaint);

    // 4. RIVETS ON CORNER
    final rivetPaint = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawCircle(const Offset(8, 8), 2, rivetPaint);
    canvas.drawCircle(const Offset(25, 8), 2, rivetPaint);
    canvas.drawCircle(const Offset(8, 25), 2, rivetPaint);

    // 5. BLUEPRINT SKETCHES (Slightly more visible)
    final blueprintPaint = Paint()
      ..color = const Color(0xFF4A90E2).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;

    _drawBlueprintCog(canvas, Offset(size.x * 0.15, size.y * 0.25), 6, blueprintPaint);
    _drawBlueprintCog(canvas, Offset(size.x * 0.85, size.y * 0.75), 10, blueprintPaint);

    // 6. DEEP VIGNETTE
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
        stops: const [0.4, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, shadowPaint);
  }


  void _drawBlueprintCog(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    const teeth = 8;
    for (var i = 0; i < teeth; i++) {
        final angle = (i * 2 * 3.14159) / teeth;
        final start = const Offset(1, 0).rotate(angle) * (radius * 0.8);
        final end = const Offset(1, 0).rotate(angle) * (radius * 1.2);
        canvas.drawLine(center + start, center + end, paint);
    }
  }

  void _drawBlueprintPipe(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    canvas.drawLine(start + const Offset(0, 0.5), end + const Offset(0, 0.5), paint);
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
