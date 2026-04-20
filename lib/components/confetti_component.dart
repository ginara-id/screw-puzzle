import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class ConfettiComponent extends ParticleSystemComponent with HasGameRef {
  ConfettiComponent() : super(priority: 1001);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    final rnd = Random();
    particle = Particle.generate(
      count: 40,
      lifespan: 2.0,
      generator: (i) {
        final startPos = Vector2(
          (rnd.nextDouble() - 0.5) * 15, // World width centered
          gameRef.camera.viewfinder.position.y - 15, // Above current view
        );
        
        final color = (rnd.nextBool()) ? const Color(0xFFFFD700) : const Color(0xFFB8860B);
        
        return AcceleratedParticle(
          acceleration: Vector2(0, 150), // Gravity pulls down
          speed: Vector2(rnd.nextDouble() * 100 - 50, 100 + rnd.nextDouble() * 100),
          position: startPos,
          child: RotatingParticle(
            to: rnd.nextDouble() * 2 * pi,
            child: ComputedParticle(
              renderer: (canvas, particle) {
                canvas.drawRect(
                  const Rect.fromLTWH(-4, -2, 8, 4),
                  Paint()..color = color,
                );
              },
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      removeFromParent();
    });
  }
}
