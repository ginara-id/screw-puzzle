import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../game/screw_game.dart';

class BoltComponent extends BodyComponent<ScrewPuzzleGame>
    with TapCallbacks
    implements PositionProvider, ScaleProvider {
  final double radius;
  final Vector2 initialPosition;

  BoltComponent({required this.initialPosition, this.radius = 0.5})
    : super(renderBody: false);

  bool _isLifted = false;
  bool get isLifted => _isLifted;
  set isLifted(bool value) {
    _isLifted = value;
    if (body.fixtures.isNotEmpty) {
      final filter = body.fixtures.first.filterData;
      filter.maskBits = value ? 0x0000 : ScrewPuzzleGame.kPlateCategory;
      body.fixtures.first.filterData = filter;
    }

    if (value) {
      add(
        ScaleEffect.to(
          Vector2.all(1.1),
          EffectController(duration: 0.3, reverseDuration: 0.3, infinite: true),
        ),
      );
    } else {
      children.whereType<ScaleEffect>().forEach((e) => e.removeFromParent());
      scale = Vector2.all(1.0);
    }
  }


  @override
  Vector2 get position => body.position;

  @override
  set position(Vector2 val) => body.setTransform(val, body.angle);

  Vector2 _scale = Vector2.all(1.0);
  @override
  Vector2 get scale => _scale;
  @override
  set scale(Vector2 value) => _scale = value;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    priority = 3;
  }

  @override
  void render(Canvas canvas) {
    // 1. PSEUDO-3D CORE BOLT RENDERING
    // Renders at Offset.zero (physics center)

    // SCALE & SHADOW CALCULATION
    final scaleFactor = (isLifted ? 1.3 : 1.0) * scale.x;
    final shadowOffset = isLifted ? const Offset(0.2, 0.4) : Offset.zero;
    final blurIntensity = isLifted ? 0.2 : 0.08;

    // Dynamic Symmetrical Shadow/Glow (Centering Lock)
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isLifted ? 0.6 : 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurIntensity);

    canvas.drawCircle(shadowOffset, radius, shadowPaint);

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    // Metallic Head (Polished Brass)
    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.2),
        colors: [
          const Color(0xFFFFD700), // Gold
          const Color(0xFFDAA520), // Goldenrod
          const Color(0xFFB8860B), // Dark Goldenrod
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect);

    canvas.save();
    canvas.scale(scaleFactor);

    // 1.5 SCREW THREADS (Visual only when lifted)
    if (isLifted) {
      final threadPaint = Paint()
        ..color = const Color(0xFFDAA520).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05;

      for (var i = 0; i < 5; i++) {
        final y = radius * (0.2 + (i * 0.15));
        canvas.drawLine(Offset(-radius * 0.8, y), Offset(radius * 0.8, y + 0.1), threadPaint);
      }
    }

    canvas.drawCircle(Offset.zero, radius, headPaint);

    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.03;
    canvas.drawCircle(Offset.zero, radius * 0.95, rimPaint);

    // PHILLIP SLOT (Engineered look)
    final slotPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12
      ..strokeCap = StrokeCap.round;

    if (isLifted) {
      canvas.rotate(0.35); 
    }

    // DRAW THE CROSS SLOTS
    canvas.drawLine(Offset(-radius * 0.4, 0), Offset(radius * 0.4, 0), slotPaint);
    canvas.drawLine(Offset(0, -radius * 0.4), Offset(0, radius * 0.4), slotPaint);

    canvas.restore();

  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      type: BodyType.static,
    );

    final shape = CircleShape()..radius = radius;
    final fixtureDef = FixtureDef(shape)
      ..friction = 0.3
      ..restitution = 0.1
      ..filter.categoryBits = ScrewPuzzleGame.kBoltHoleCategory
      ..filter.maskBits = ScrewPuzzleGame.kPlateCategory;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  bool containsLocalPoint(Vector2 point) => point.length <= radius * 1.5;

  @override
  void onTapDown(TapDownEvent event) {
    game.onBoltTapped(this);
  }

  void shake() {
    add(
      MoveByEffect(
        Vector2(0.2, 0),
        EffectController(duration: 0.1, reverseDuration: 0.1, repeatCount: 2),
      ),
    );
  }

  void moveTo(Vector2 target, {VoidCallback? onComplete}) {
    isLifted = true; // Ensure lifted state during kinematic transit
    body.setType(BodyType.kinematic);
    add(
      MoveToEffect(
        target,
        EffectController(duration: 0.3, curve: Curves.easeInOut),
        onComplete: () {
          isLifted = false; // Restore normal state upon landing
          if (onComplete != null) onComplete();
        },
      ),
    );
  }
}
