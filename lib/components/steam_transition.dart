import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class SteamTransitionComponent extends ParticleSystemComponent with HasGameRef {
  final VoidCallback onComplete;

  SteamTransitionComponent({required this.onComplete}) : super(priority: 1000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    final rnd = Random();
    particle = Particle.generate(
      count: 50,
      lifespan: 1.5,
      generator: (i) {
        final startPos = Vector2(
          rnd.nextDouble() * gameRef.size.x,
          gameRef.size.y + 50,
        );
        
        return AcceleratedParticle(
          acceleration: Vector2(0, -200),
          speed: Vector2(rnd.nextDouble() * 100 - 50, -300 - rnd.nextDouble() * 200),
          position: startPos,
          child: CircleParticle(
            radius: 20 + rnd.nextDouble() * 30,
            paint: Paint()
              ..color = Colors.white.withOpacity(0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          ),
        );
      },
    );

    // Self-destruct and trigger callback
    Future.delayed(const Duration(milliseconds: 1500), () {
      removeFromParent();
      onComplete();
    });
  }
}
