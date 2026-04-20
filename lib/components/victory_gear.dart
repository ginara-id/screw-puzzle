import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class VictoryGear extends PositionComponent with HasGameRef implements OpacityProvider {
  VictoryGear() : super(priority: 500);

  double _opacity = 1.0;
  @override
  double get opacity => _opacity;
  @override
  set opacity(double value) => _opacity = value;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(8, 8);
    position = gameRef.size / 2;
    anchor = Anchor.center;

    // Success Text
    add(
      TextComponent(
        text: 'LEVEL SUCCESS!',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 1.5, // World units
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
            fontFamily: 'Courier',
            shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0.1, 0.1))],
          ),
        ),
        position: Vector2(0, -size.y * 0.4),
        anchor: Anchor.center,
      ),
    );

    // Fade in and Spin
    add(OpacityEffect.fadeIn(EffectController(duration: 0.5)));
    add(RotateEffect.by(2 * math.pi, EffectController(duration: 2, repeatCount: 1)));
    
    // Scale pulse
    add(ScaleEffect.to(Vector2.all(1.2), EffectController(duration: 0.8, reverseDuration: 0.8, repeatCount: 1)));

    // Self-destruct after animation
    Future.delayed(const Duration(seconds: 3), () {
      removeFromParent();
    });
  }


  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withOpacity(opacity),
          const Color(0xFFB8860B).withOpacity(opacity),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Draw Cog
    canvas.drawCircle(center, radius * 0.7, paint);
    const teeth = 12;
    for (var i = 0; i < teeth; i++) {
        final angle = (i * 2 * math.pi) / teeth;
        final rect = Rect.fromCenter(
          center: center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.8),
          width: radius * 0.3,
          height: radius * 0.2,
        );
        canvas.save();
        canvas.translate(rect.center.dx, rect.center.dy);
        canvas.rotate(angle);
        canvas.drawRect(Rect.fromLTWH(-rect.width/2, -rect.height/2, rect.width, rect.height), paint);
        canvas.restore();
    }

    // Hole in center
    final holePaint = Paint()
      ..color = Colors.black.withOpacity(0.5 * opacity)
      ..blendMode = BlendMode.dstOut;
    canvas.drawCircle(center, radius * 0.2, holePaint);
  }
}
