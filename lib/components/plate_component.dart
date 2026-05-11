import 'dart:ui';
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
  int _activeContacts = 0; // Counts current active collision touching state

  /// Called by ScrewGame to freeze/unfreeze this plate
  void setHardPinned(bool value) => _isHardPinned = value;

  /// Enable or disable physical collision with bolts.
  /// Must REASSIGN filterData (not just mutate) to trigger Forge2D refilter.
  void setCollisionEnabled(bool enabled) {
    for (final fixture in body.fixtures) {
      final filter = fixture.filterData; // get current
      filter.maskBits = enabled ? ScrewPuzzleGame.kBoltHoleCategory : 0;
      fixture.filterData =
          filter; // reassign → triggers world.refilter() internally
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
    // SAFETY FALLBACK: During synchronous object initialization, Forge2D internal transform grids
    // might not have fully committed the body's initial position state. 
    // Using static raw math subtraction (worldPos - initialPosition) is 100% robust 
    // and guarantees pixel-perfect coordinate consistency before physics ticking begins.
    final localPos = (body.angle.abs() < 0.001)
        ? (worldPos - initialPosition)
        : body.localPoint(worldPos);

    // MICRO-ALIGNMENT SNAP: Scan for any existing hole close to the new position.
    final existingIndex = _localHoles.indexWhere((h) => (h - localPos).length < 0.35);
    
    if (existingIndex >= 0) {
      // If a slight offset exists due to runtime physics drift, forcefully update 
      // the hole's internal coordinates to EXACTLY match the current bolt placement.
      // This mathematically guarantees the user NEVER sees an off-center metallic lip overlap!
      final double dist = (_localHoles[existingIndex] - localPos).length;
      if (dist > 0.01) {
        _localHoles[existingIndex] = localPos;
        _buildCachedPath(); 
      }
    } else {
      // Found a truly new position! Add new geometry and rebuild the picture cache
      _localHoles.add(localPos);
      _buildCachedPath();
    }
  }

  double _errorFlashTimer = 0;
  void flashError() {
    _errorFlashTimer = 0.5;
  }

  Picture? _cachedPlatePicture; // HOLY GRAIL CACHE: Holds the entire static visuals
  late Path _platePath;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    priority = 2;
    _initPaints(); // Initialize paint system first
    _buildCachedPath(); // Then use the paints for pre-recording
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

    _glintPaint = Paint()..blendMode = BlendMode.screen;
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
    } else    if (shapeType == PlateShape.triangle) {
      // CENTROID CENTERING FIX: Moving the visual path origin to match 
      // the mathematical mass-centroid (Top vertex at -2/3 Height, Base at 1/3 Height).
      // This prevents Forge2D physics from applying auto-corrective shifts that break hole alignment.
      mainPath = Path()
        ..moveTo(0, -size.y * (2/3))
        ..lineTo(-size.x / 2, size.y / 3)
        ..lineTo(size.x / 2, size.y / 3)
        ..close();
    } else {
      mainPath = Path()..addRect(rect);
    }

    final holesPath = Path();
    for (final localPos in _localHoles) {
      holesPath.addOval(
        Rect.fromCircle(center: Offset(localPos.x, localPos.y), radius: 0.40),
      );
    }

    // 1. Precalculate complex Path geometry first
    _platePath = Path.combine(PathOperation.difference, mainPath, holesPath);

    // 2. NEW MASTER OPTIMIZATION: Pre-Record entire static visual look to GPU
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Pre-generate shader matching current size boundaries
    _surfacePaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [Color(0xFF424242), Color(0xFF616161), Color(0xFF212121)],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);

    // Record Part A: Base Surface Gradient
    canvas.drawPath(_platePath, _surfacePaint);

    // Record Part B: Scratches & Wear details
    canvas.drawLine(
      Offset(-size.x / 2.2, size.y / 4),
      Offset(size.x / 4, -size.y / 3),
      _scratchPaint,
    );

    // Record Part C: EXTERIOR BORDER ONLY.
    // Re-routing to mainPath draws outlines purely around the outer perimeter, 
    // satisfying user demand to remove noisy borders from the hole interiors.
    canvas.drawPath(mainPath, _borderPaint);

    // Part D: Rim depth effects REMOVED as per user design request for cleanest holes

    // Capture the completed raster command buffer and save it to reusable hardware memory
    _cachedPlatePicture = recorder.endRecording();
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

    // SMART STABILIZATION V2: Only run braking when ACTIVELY TOUCHING a bolt/surface
    // If free-falling or free-swinging (_activeContacts == 0), do NOT brake -> Full agility!
    if (body.isAwake && _activeContacts > 0) {
      final double linVel = body.linearVelocity.length;
      final double angVel = body.angularVelocity.abs();

      // Stop tiny micro-movements instantly without waiting for BOTH axis conditions
      bool shouldFreezeLin = false;
      bool shouldFreezeAng = false;

      // 1. Ultra-Low Speed Linear braking (Only catches microscopic crawl)
      if (linVel < 0.3) {
        body.linearVelocity.scale(0.5); 
        if (linVel < 0.1) shouldFreezeLin = true;
      }

      // 2. Ultra-Low Speed Angular braking
      if (angVel < 0.3) {
        body.angularVelocity *= 0.5; 
        if (angVel < 0.1) shouldFreezeAng = true;
      }

      // 3. Ultimate Sleep Override: If BOTH directions are basically inert, KILL state
      if (shouldFreezeLin && shouldFreezeAng) {
        body.linearVelocity = Vector2.zero();
        body.angularVelocity = 0;
        body.setAwake(false); // Unconditional hibernation -> 100% Jitter Prevention
      }
    }
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      type: BodyType.dynamic,
      linearDamping: 0.0,  // ZERO drag for max agility
      angularDamping: 0.0, // Raw frictionless physics
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
            Vector2(0, -size.y * (2/3)),
            Vector2(-size.x / 2, size.y / 3),
            Vector2(size.x / 2, size.y / 3),
          ]);
        break;
      case PlateShape.box:
      default:
        shape = PolygonShape()
          ..setAsBox(size.x / 2, size.y / 2, Vector2.zero(), 0);
        break;
    }

    final fixtureDef = FixtureDef(shape)
      ..density = 0.5   // Increased weight so it naturally forces itself down and away from bolts
      ..friction = 0.15 // Reduced to SLIPPERY levels so it slides across bolts instead of gluing to them
      ..restitution = 0.2 // Adds slight elastic bounce off solid surfaces
      ..filter.categoryBits = ScrewPuzzleGame.kPlateCategory
      ..filter.maskBits = ScrewPuzzleGame
          .kBoltHoleCategory; // Enable collision by default to avoid initialization race conditions

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);
    _activeContacts++; // Plate is now actively pushing against something

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

        // Dropped threshold significantly (12.0 -> 3.0) so small knocks now satisfy the auditory industrial feedback
        if (relativeVelocity > 3.0) {
          // Dynamic volume scaling for varied auditory landscape
          final impactVolume = (relativeVelocity / 20.0).clamp(0.15, 1.0);
          gameRef.audio.playPlateCollision(volume: impactVolume);

          if (relativeVelocity > 8.0) {
            showSparks(point);
          }

          // Trigger subtle camera shake on heavy mechanical impacts
          if (relativeVelocity > 18.0) {
            gameRef.shakeCamera(intensity: 0.4);
          }
        }
      }
    }
  }

  @override
  void endContact(Object other, Contact contact) {
    super.endContact(other, contact);
    _activeContacts = (_activeContacts - 1).clamp(0, 999);
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
          // Cache static visual variables outside per-frame renderer loop
          final dirVector = Vector2(cos(angle), sin(angle)) * 0.6;
          final renderPaint = Paint()
            ..strokeWidth = 0.15
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          return AcceleratedParticle(
            acceleration: Vector2(0, 60),
            speed: Vector2(cos(angle) * speed, sin(angle) * speed),
            position: contactPoint.clone(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final fade = particle.progress > 0.5
                    ? (1 - particle.progress) * 2
                    : 1.0;
                // Reuse the cached paint instance rather than instantiating new Memory every tick
                canvas.drawLine(
                  Offset.zero,
                  Offset(dirVector.x, dirVector.y),
                  renderPaint..color = Colors.orangeAccent.withOpacity(fade),
                );
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


    // 2. NEW GOD-TIER OPTIMIZATION: Direct Hardware Acceleration Draw
    // Instead of looping over layers and holes every frame, blast the pre-recorded picture instantly
    if (_cachedPlatePicture != null) {
      canvas.drawPicture(_cachedPlatePicture!);
    }

    // 3. Optimized Glint (Still dynamic because position translates based on timer)
    final glintProgress = (_glintTimer % 5.0) / 5.0;
    final glintX = -size.x + (glintProgress * size.x * 6);

    _glintShader ??= LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.15),
        Colors.white.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, -size.y, size.x * 0.4, size.y * 2));

    _glintPaint.shader = _glintShader;

    canvas.save();
    canvas.clipPath(_platePath);
    canvas.translate(glintX, 0);
    // SAFETY BOUNDING: Using restricted DrawRect ensures absolute zero bleed outside the clip region,
    // preventing accidental white-screen fill artifacts on certain hardware.
    canvas.drawRect(Rect.fromLTWH(-size.x * 2, -size.y * 2, size.x * 4, size.y * 4), _glintPaint);
    canvas.restore();
  }
  
  @override
  void onRemove() {
    // Clean up hardware picture buffer memory when object is discarded
    _cachedPlatePicture?.dispose();
    super.onRemove();
  }
}
