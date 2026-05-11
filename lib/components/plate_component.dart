import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;
import 'package:flutter/material.dart';
import 'dart:math';
import '../game/screw_game.dart';
import 'bolt_component.dart';

enum PlateShape { box, circle, triangle }

class PlateComponent extends BodyComponent<ScrewPuzzleGame>
    with HasGameRef<ScrewPuzzleGame>, ContactCallbacks {
  final Vector2 size;
  final Vector2 initialPosition;
  final PlateShape shapeType;

  PlateComponent({
    required this.size,
    required this.initialPosition,
    this.shapeType = PlateShape.box,
  });

  final List<Vector2> _localHoles = [];
  double _glintTimer = Random().nextDouble() * 3.0;
  bool _isHardPinned = false; // true when held by 2+ joints

  /// Called by ScrewGame to freeze/unfreeze this plate
  void setHardPinned(bool value) => _isHardPinned = value;

  /// Enable or disable physical collision with bolts.
  /// Must REASSIGN filterData (not just mutate) to trigger Forge2D refilter.
  void setCollisionEnabled(bool enabled) {
    for (final fixture in body.fixtures) {
      final filter = fixture.filterData; // get current
      filter.maskBits = enabled ? ScrewPuzzleGame.kBoltHoleCategory : 0;
      fixture.filterData = filter; // reassign → triggers world.refilter() internally
    }
  }

  
  // CACHED PAINTS & SHADERS for performance
  late final Paint _shadowPaint;
  late final Paint _surfacePaint;
  late final Paint _borderPaint;
  late final Paint _rimPaint;
  late final Paint _depthPaint;
  late final Paint _scratchPaint;
  late final Paint _glintPaint;
  Rect? _lastRect;
  Shader? _surfaceShader;
  Shader? _glintShader;



  List<Vector2> get localHoles => List.unmodifiable(_localHoles);

  void addHole(Vector2 worldPos) {
    final localPos = body.isActive
        ? body.localPoint(worldPos)
        : worldPos - initialPosition;

    bool exists = _localHoles.any((h) => (h - localPos).length < 0.2);
    if (!exists) {
      _localHoles.add(localPos);
      _buildCachedPath(); // Refresh the visual path to show the new hole
    }
  }

  double _errorFlashTimer = 0;
  void flashError() {
    _errorFlashTimer = 0.5;
  }

  late Path _platePath;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    priority = 2;
    _buildCachedPath();
    _initPaints();
  }

  void _initPaints() {
    _shadowPaint = Paint()..color = Colors.black.withOpacity(0.3);
    
    _surfacePaint = Paint();
    
    _borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06;

    _rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;

    _depthPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1;

    _scratchPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;

    _glintPaint = Paint()
      ..blendMode = BlendMode.screen;
  }

  void _buildCachedPath() {
    Path mainPath;
    final radius = size.x / 2;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );

    if (shapeType == PlateShape.circle) {
      mainPath = Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
    } else if (shapeType == PlateShape.triangle) {
      mainPath = Path()
        ..moveTo(0, -size.y / 2)
        ..lineTo(-size.x / 2, size.y / 2)
        ..lineTo(size.x / 2, size.y / 2)
        ..close();
    } else {
      mainPath = Path()..addRect(rect);
    }

    final holesPath = Path();
    for (final localPos in _localHoles) {
      // Use exact radius as defined in gameplay logic
      holesPath.addOval(
        Rect.fromCircle(center: Offset(localPos.x, localPos.y), radius: 0.40),
      );
    }

    // Precalculate the complex shape once, saving massive amounts of GPU memory
    _platePath = Path.combine(PathOperation.difference, mainPath, holesPath);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_errorFlashTimer > 0) {
      _errorFlashTimer -= dt;
    }
    _glintTimer += dt;

    // Kill all physics-solver residual velocity every frame when fully pinned
    if (_isHardPinned) {
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0;
      return;
    }

    // SMART STABILIZATION: Dampen and Force Sleep on resting contacts to eliminate all jitter
    if (body.isAwake) {
      final linVel = body.linearVelocity.length;
      final angVel = body.angularVelocity.abs();

      // 1. Damping Zone: Start aggressively bleeding energy when moving slowly
      if (linVel < 0.8 && angVel < 0.8) {
        body.linearVelocity.scale(0.90);
        body.angularVelocity *= 0.90;

        // 2. Snap Zone: If near standstill, hard-reset and FORCE SLEEP
        if (linVel < 0.1 && angVel < 0.1) {
          body.linearVelocity = Vector2.zero();
          body.angularVelocity = 0;
          body.setAwake(false); // Eliminates processing entirely -> ZERO jitter
        }
      }
    }
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      type: BodyType.dynamic,
      linearDamping: 0.5,
      angularDamping: 0.5,
      gravityScale: Vector2.all(1.0),
      allowSleep: true,
      bullet: true, // Continuous collision detection active from the start
    );

    Shape shape;
    switch (shapeType) {
      case PlateShape.circle:
        shape = CircleShape()..radius = size.x / 2;
        break;
      case PlateShape.triangle:
        shape = PolygonShape()
          ..set([
            Vector2(0, -size.y / 2),
            Vector2(-size.x / 2, size.y / 2),
            Vector2(size.x / 2, size.y / 2),
          ]);
        break;
      case PlateShape.box:
      default:
        shape = PolygonShape()
          ..setAsBox(size.x / 2, size.y / 2, Vector2.zero(), 0);
        break;
    }

    final fixtureDef = FixtureDef(shape)
      ..density = 0.3
      ..friction = 0.8 // Raised friction ensures plates 'stick' securely and stabilize faster
      ..restitution = 0.0
      ..filter.categoryBits = ScrewPuzzleGame.kPlateCategory
      ..filter.maskBits = ScrewPuzzleGame.kBoltHoleCategory; // Enable collision by default to avoid initialization race conditions

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);

    // Only trigger sparks if the relative velocity is high enough
    if (other is PlateComponent || other is BoltComponent) {
      // Logic removed
    }

    if (other is BoltComponent) {
      final worldManifold = WorldManifold();
      contact.getWorldManifold(worldManifold);

      if (worldManifold.points.isNotEmpty) {
        final point = worldManifold.points.first;
        final relativeVelocity =
            (body.linearVelocity - other.body.linearVelocity).length;

        if (relativeVelocity > 12.0) {
          final impactVolume = (relativeVelocity / 30.0).clamp(0.2, 1.0);
          gameRef.audio.playPlateCollision(volume: impactVolume);
          showSparks(point);

          // --- ADDED: Camera Shake on impact ---
          if (relativeVelocity > 18.0) {
            gameRef.shakeCamera(intensity: 0.4);
          }
        }
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (body.fixtures.isEmpty) return false;
    return body.fixtures.first.testPoint(body.worldPoint(point));
  }

  bool isOverlappingCircle(Vector2 worldPos, double radius) {
    if (body.fixtures.isEmpty) return false;

    // For circles, use distance check for better accuracy
    if (shapeType == PlateShape.circle) {
      final localPoint = body.localPoint(worldPos);
      return localPoint.length < (size.x / 2 + radius);
    }

    // For other shapes, use the fixture test with a small tolerance
    // This is more robust for triangles and boxes
    return body.fixtures.first.testPoint(worldPos);
  }

  bool isHoleAligned(Vector2 worldPos, {double tolerance = 0.2}) {
    final localPoint = body.localPoint(worldPos);
    for (final holePos in _localHoles) {
      if ((holePos - localPoint).length <= tolerance) {
        return true;
      }
    }
    return false;
  }

  void showSparks(Vector2 contactPoint) {
    final rnd = Random();
    final particle = ParticleSystemComponent(
      particle: Particle.generate(
        count: 8,
        lifespan: 0.15 + rnd.nextDouble() * 0.15,
        generator: (i) {
          final angle = rnd.nextDouble() * pi * 2;
          final speed = 12 + rnd.nextDouble() * 20;
          return AcceleratedParticle(
            acceleration: Vector2(0, 60),
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

    // 1. Optimized Shadow
    final shadowOffsetVec = Vector2(0.15, 0.3)..rotate(-body.angle);
    canvas.drawPath(_platePath.shift(Offset(shadowOffsetVec.x, shadowOffsetVec.y)), _shadowPaint);

    // 2. Surface (Shader Caching)
    if (_lastRect != rect || _surfaceShader == null) {
      _lastRect = rect;
      _surfaceShader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFF424242), Color(0xFF616161), Color(0xFF212121)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    }
    _surfacePaint.shader = _surfaceShader;
    canvas.drawPath(_platePath, _surfacePaint);

    // 3. Wear & Scratches
    canvas.drawLine(
      Offset(-size.x / 2.2, size.y / 4),
      Offset(size.x / 4, -size.y / 3),
      _scratchPaint,
    );

    // 4. Border
    canvas.drawPath(_platePath, _borderPaint);

    // 5. Optimized Glint (Using translation to avoid shader re-creation)
    final glintProgress = (_glintTimer % 5.0) / 5.0;
    final glintX = -size.x + (glintProgress * size.x * 6);
    
    if (_glintShader == null) {
      _glintShader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, -size.y, size.x * 0.4, size.y * 2));
    }
    
    _glintPaint.shader = _glintShader;
    
    canvas.save();
    canvas.clipPath(_platePath);
    canvas.translate(glintX, 0);
    canvas.drawPaint(_glintPaint);
    canvas.restore();

    // 6. Rims
    for (final localPos in _localHoles) {
      final offset = Offset(localPos.x, localPos.y);
      canvas.drawCircle(offset, 0.40, _rimPaint);
      canvas.drawCircle(offset, 0.38, _depthPaint);
    }
  }
}
