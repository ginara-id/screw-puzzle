import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class LevelClearEffect extends PositionComponent with HasGameRef {
  double _radius = 0;
  double _opacity = 1.0;
  final List<_Particle> _particles = [];

  LevelClearEffect() : super(priority: 1001);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set position to center of the screen (viewport)
    position = gameRef.camera.viewport.size / 2;
    
    // Generate particles
    final rnd = Random();
    for (var i = 0; i < 30; i++) {
      final angle = rnd.nextDouble() * 2 * pi;
      final speed = 10.0 + rnd.nextDouble() * 20.0;
      _particles.add(
        _Particle(
          position: Vector2.zero(),
          velocity: Vector2(cos(angle) * speed, sin(angle) * speed),
          size: 0.2 + rnd.nextDouble() * 0.4,
          life: 1.0 + rnd.nextDouble(),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Expanding shockwave ring
    _radius += dt * 30.0;
    _opacity = max(0, _opacity - dt * 1.5);

    // Update particles
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.velocity *= 0.95; // Friction
      p.life -= dt * 2.0;
    }
    
    _particles.removeWhere((p) => p.life <= 0);

    if (_opacity <= 0 && _particles.isEmpty) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_opacity > 0) {
      // Draw Expanding Shockwave
      final ringPaint = Paint()
        ..color = Colors.white.withOpacity(_opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset.zero, _radius, ringPaint);
      
      final innerRingPaint = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(_opacity * 0.8) // Cyan inner ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawCircle(Offset.zero, _radius * 0.9, innerRingPaint);
    }

    // Draw Particles
    for (final p in _particles) {
      if (p.life > 0) {
        final pOpacity = (p.life).clamp(0.0, 1.0);
        final paint = Paint()
          ..color = const Color(0xFF00B4DB).withOpacity(pOpacity) // Deep Cyan particles
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5); // More glow
        canvas.drawCircle(p.position.toOffset(), p.size, paint);
        
        // Core
        final corePaint = Paint()
          ..color = Colors.white.withOpacity(pOpacity);
        canvas.drawCircle(p.position.toOffset(), p.size * 0.5, corePaint);
      }
    }
  }
}

class _Particle {
  Vector2 position;
  Vector2 velocity;
  double size;
  double life;

  _Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.life,
  });
}
