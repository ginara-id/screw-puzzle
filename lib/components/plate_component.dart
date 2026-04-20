import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/rendering.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;
import 'package:flutter/material.dart';
import 'dart:math';
import '../game/screw_game.dart';
import 'hole_component.dart';

class PlateComponent extends BodyComponent<ScrewPuzzleGame>
    with HasGameRef<ScrewPuzzleGame> {
  final Vector2 size;
  final Vector2 initialPosition;

  PlateComponent({required this.size, required this.initialPosition});

  final List<Vector2> _localHoles = [];

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
  bool containsLocalPoint(Vector2 point) {
    return point.x.abs() <= size.x / 2 && point.y.abs() <= size.y / 2;
  }

  /// 2. AAA Polish - Spark Particles on Detachment
  void showSparks(Vector2 contactPoint) {
    final rnd = Random();
    final particle = ParticleSystemComponent(
      particle: Particle.generate(
        count: 15,
        lifespan: 0.4,
        generator: (i) => AcceleratedParticle(
          acceleration: Vector2(0, 50), // Gravity
          speed: Vector2(rnd.nextDouble() * 20 - 10, rnd.nextDouble() * -20),
          position: contactPoint.clone(),
          child: CircleParticle(
            radius: 0.1,
            paint: Paint()..color = Colors.orangeAccent,
          ),
        ),
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

    // 1. PSEUDO-3D DROP SHADOW (Offset x:2, y:4 in world units is huge, so we scale it)
    final shadowOffset = const Offset(0.2, 0.4);
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2);
    canvas.drawRect(rect.shift(shadowOffset), shadowPaint);

    // --- START PUNCH-OUT RENDERING ---
    // We save a layer to perform 'holes' using BlendMode.dstOut
    canvas.saveLayer(rect, Paint());

    // 2. AGED COPPER SURFACE
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFB87333), // Copper Base
          Color(0xFF8B4513), // Bronze Shadow
          Color(0xFF4E733E), // Verdigris (Greenish rust)
          Color(0xFFB87333),
        ],
        stops: const [0.0, 0.4, 0.8, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, paint);

    // 2.5 SURFACE SCRATCHES
    final scratchPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
    canvas.drawLine(Offset(-size.x / 2, -size.y / 2), Offset(size.x / 2, size.y / 2), scratchPaint);
    canvas.drawLine(Offset(size.x / 4, -size.y / 2), Offset(-size.x / 4, size.y / 2), scratchPaint);


    // 3. ERROR FLASH
    if (_errorFlashTimer > 0) {
      final flashPaint = Paint()
        ..color = Colors.red.withOpacity(
          0.3 * (sin(_errorFlashTimer * 20) * 0.5 + 0.5),
        );
      canvas.drawRect(rect, flashPaint);
    }

    // 4. BEVELED EDGES
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    canvas.drawRect(rect, borderPaint);

    // 5. THE PUNCH (Drilled holes in this wood)
    final punchPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill;

    for (final localPos in _localHoles) {
      canvas.drawCircle(Offset(localPos.x, localPos.y), 0.5, punchPaint);
    }

    // Restore layer to composite back with transparency
    canvas.restore();

    // 6. BRASS RIVETS & DEPTH
    final rivetRadius = size.x * 0.04;
    final inset = rivetRadius * 2.5;

    final brassRivetPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFD700), const Color(0xFFB8860B)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: rivetRadius));

    final rivetShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
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
