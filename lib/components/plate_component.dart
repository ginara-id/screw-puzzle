import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;
import 'package:flutter/material.dart';
import 'dart:math';
import '../game/screw_game.dart';
import 'bolt_component.dart';

class PlateComponent extends BodyComponent<ScrewPuzzleGame>
    with HasGameRef<ScrewPuzzleGame>, ContactCallbacks {
  final Vector2 size;
  final Vector2 initialPosition;

  PlateComponent({required this.size, required this.initialPosition});

  final List<Vector2> _localHoles = [];
  double _glintTimer = Random().nextDouble() * 3.0; // Randomize start phase

  bool isHoleAligned(Vector2 worldPos, {double tolerance = 0.2}) {
    final localPoint = body.localPoint(worldPos);
    for (final holePos in _localHoles) {
      if ((holePos - localPoint).length <= tolerance) {
        return true;
      }
    }
    return false;
  }

  void addHole(Vector2 worldPos) {
    if (body.isActive) {
      _localHoles.add(body.localPoint(worldPos));
    } else {
      // Fallback for initialization phase
      _localHoles.add(worldPos - initialPosition);
    }
  }

  double _errorFlashTimer = 0;
  void flashError() {
    _errorFlashTimer = 0.5;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Layer 2: Plates (Priority 2)
    priority = 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_errorFlashTimer > 0) {
      _errorFlashTimer -= dt;
    }
    _glintTimer += dt;
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      type: BodyType.dynamic,
      linearDamping: 0.5, // Smoother, more controlled movement
      angularDamping: 0.5,
      gravityScale: Vector2(0, 1.5),
      allowSleep: true,
    );

    final shape = PolygonShape()
      ..setAsBox(size.x / 2, size.y / 2, Vector2.zero(), 0);

    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..friction = 0.05 // Reduced friction for smoothness
      ..restitution = 0.05 // Low bounce
      ..filter.categoryBits = ScrewPuzzleGame.kPlateCategory
      ..filter.maskBits = ScrewPuzzleGame.kBoltHoleCategory; // ONLY collide with bolts, not other plates

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is BoltComponent) {
      final worldManifold = WorldManifold();
      contact.getWorldManifold(worldManifold);

      if (worldManifold.points.isNotEmpty) {
        final point = worldManifold.points.first;

        // Calculate relative velocity
        final v1 = body.linearVelocity;
        final v2 = other.body.linearVelocity;
        final relativeVelocity = (v1 - v2).length;

        // Only spawn sparks on heavy metal collisions
        if (relativeVelocity > 12.0) {
          final impactVolume = (relativeVelocity / 30.0).clamp(0.2, 1.0);
          gameRef.audio.playPlateCollision(volume: impactVolume);
          showSparks(point);
        }
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x.abs() <= size.x / 2 && point.y.abs() <= size.y / 2;
  }

  /// Strict check: Does this plate overlap ANY part of a circle at [worldPos] with [radius]?
  bool isOverlappingCircle(Vector2 worldPos, double radius) {
    final localPoint = body.localPoint(worldPos);
    
    // Find the closest point on the rectangle to the circle center
    final halfW = size.x / 2;
    final halfH = size.y / 2;
    
    final closestX = localPoint.x.clamp(-halfW, halfW);
    final closestY = localPoint.y.clamp(-halfH, halfH);
    
    // Calculate distance from closest point to circle center
    final distanceX = localPoint.x - closestX;
    final distanceY = localPoint.y - closestY;
    
    final distanceSquared = (distanceX * distanceX) + (distanceY * distanceY);
    return distanceSquared < (radius * radius);
  }

  /// AAA Polish - Realistic Metal Spark Particles
  void showSparks(Vector2 contactPoint) {
    final rnd = Random();
    final particle = ParticleSystemComponent(
      particle: Particle.generate(
        count: 15,
        lifespan: 0.2 + rnd.nextDouble() * 0.2,
        generator: (i) {
          final angle = rnd.nextDouble() * pi * 2;
          final speed = 15 + rnd.nextDouble() * 25;
          return AcceleratedParticle(
            acceleration: Vector2(0, 60), // Heavy Gravity
            speed: Vector2(cos(angle) * speed, sin(angle) * speed),
            position: contactPoint.clone(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final fade = particle.progress > 0.5
                    ? (1 - particle.progress) * 2
                    : 1.0;
                final paint = Paint()
                  ..color = Colors.orangeAccent.withOpacity(fade)
                  ..strokeWidth = 0.15
                  ..style = PaintingStyle.stroke
                  ..strokeCap = StrokeCap.round;
                // Draw streaks instead of circles for fast sparks
                final dir = Vector2(cos(angle), sin(angle)) * 0.6;
                canvas.drawLine(Offset.zero, Offset(dir.x, dir.y), paint);
              },
            ),
          );
        },
      ),
    );
    parent?.add(particle);
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );

    // 1. PSEUDO-3D DROP SHADOW
    final shadowOffset = const Offset(0.2, 0.4);
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2);
    canvas.drawRect(rect.shift(shadowOffset), shadowPaint);

    // --- START PUNCH-OUT RENDERING ---
    canvas.saveLayer(rect, Paint());

    // 2. WEATHERED IRON SURFACE
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF424242), // Dark Iron
          Color(0xFF616161), // Mid Iron
          Color(0xFF212121), // Deep Iron
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, paint);

    // 4. METALLIC WEAR (Scratches & Grain)
    final scratchPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
    canvas.drawLine(
      Offset(-size.x / 2.2, size.y / 4),
      Offset(size.x / 4, -size.y / 3),
      scratchPaint,
    );

    // 5. BEVELED EDGES (Aged Metal)
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06;
    canvas.drawRect(rect, borderPaint);

    // 6. DYNAMIC GLINT (Dirty / Oily shine)
    final glintProgress = (_glintTimer % 5.0) / 5.0;
    final glintX = -size.x + (glintProgress * size.x * 6);
    final glintPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(glintX, -size.y, size.x * 0.4, size.y * 2))
      ..blendMode = BlendMode.screen;
    canvas.drawRect(rect, glintPaint);

    // 7. THE PUNCH (Drilled holes)
    final punchPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill;
    
    // Hole Rim Paint (Inner shadow/rim)
    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;

    for (final localPos in _localHoles) {
      final offset = Offset(localPos.x, localPos.y);
      canvas.drawCircle(offset, 0.40, punchPaint);
    }
    canvas.restore();

    // 8. HOLE RIMS (Drawn after restore to be visible)
    for (final localPos in _localHoles) {
      final offset = Offset(localPos.x, localPos.y);
      canvas.drawCircle(offset, 0.40, rimPaint);
      
      // Subtle depth shadow inside the hole
      final depthPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1;
      canvas.drawCircle(offset, 0.38, depthPaint);
    }

  }
}
