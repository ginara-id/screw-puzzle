import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/rendering.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;
import 'package:flutter/material.dart';
import 'dart:math';
import '../game/screw_game.dart';
import 'hole_component.dart';
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
      linearDamping: 0.5,
      angularDamping: 0.5,
    );

    final shape = PolygonShape()
      ..setAsBox(size.x / 2, size.y / 2, Vector2.zero(), 0);

    final fixtureDef = FixtureDef(shape)
      ..density = 5.0
      ..friction = 0.5
      ..restitution = 0.2
      ..filter.categoryBits = ScrewPuzzleGame.kPlateCategory
      ..filter.maskBits = ScrewPuzzleGame.kBoltHoleCategory;

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
        if (relativeVelocity > 5.0) {
          showSparks(point);
        }
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x.abs() <= size.x / 2 && point.y.abs() <= size.y / 2;
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
                final fade = particle.progress > 0.5 ? (1 - particle.progress) * 2 : 1.0;
                final paint = Paint()
                  ..color = Colors.orangeAccent.withOpacity(fade)
                  ..strokeWidth = 0.15
                  ..style = PaintingStyle.stroke
                  ..strokeCap = StrokeCap.round;
                // Draw streaks instead of circles for fast sparks
                final dir = Vector2(cos(angle), sin(angle)) * 0.6;
                canvas.drawLine(Offset.zero, Offset(dir.x, dir.y), paint);
              }
            ),
          );
        }
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

    // 2. AGED COPPER/IRON SURFACE
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFB87333), // Copper Base
          Color(0xFF8B4513), // Bronze Shadow
          Color(0xFF4E733E), // Verdigris
          Color(0xFFB87333),
        ],
        stops: const [0.0, 0.4, 0.8, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
    
    // 3. DYNAMIC METALLIC GLINT (Shine sweeps across periodically)
    final glintProgress = (_glintTimer % 3.0) / 3.0; 
    final glintX = -size.x + (glintProgress * size.x * 3);
    
    final glintPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(glintX, -size.y, size.x * 0.8, size.y * 2))
      ..blendMode = BlendMode.screen;
      
    canvas.drawRect(rect, glintPaint);

    // 4. SURFACE SCRATCHES
    final scratchPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.03;
    canvas.drawLine(Offset(-size.x / 2, -size.y / 2), Offset(size.x / 2, size.y / 2), scratchPaint);
    canvas.drawLine(Offset(size.x / 4, -size.y / 2), Offset(-size.x / 4, size.y / 2), scratchPaint);


    // 5. ERROR FLASH
    if (_errorFlashTimer > 0) {
      final flashPaint = Paint()
        ..color = Colors.red.withOpacity(
          0.3 * (sin(_errorFlashTimer * 20) * 0.5 + 0.5),
        );
      canvas.drawRect(rect, flashPaint);
    }

    // 6. BEVELED EDGES
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    canvas.drawRect(rect, borderPaint);

    // 7. THE PUNCH (Drilled holes in the metal)
    final punchPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill;

    for (final localPos in _localHoles) {
      canvas.drawCircle(Offset(localPos.x, localPos.y), 0.5, punchPaint);
    }

    // Restore layer to composite back with transparency
    canvas.restore();

    // 8. BRASS RIVETS & DEPTH
    final rivetRadius = size.x * 0.04;
    final inset = rivetRadius * 2.5;

    final brassRivetPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFD700), const Color(0xFFB8860B)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: rivetRadius));

    final rivetShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.05);

    final offsets = [
      Offset(-size.x / 2 + inset, -size.y / 2 + inset),
      Offset(size.x / 2 - inset, -size.y / 2 + inset),
      Offset(-size.x / 2 + inset, size.y / 2 - inset),
      Offset(size.x / 2 - inset, size.y / 2 - inset),
    ];

    for (final offset in offsets) {
      canvas.drawCircle(offset + const Offset(0.05, 0.05), rivetRadius, rivetShadowPaint);
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.drawCircle(Offset.zero, rivetRadius, brassRivetPaint);
      canvas.restore();
    }
  }
}
