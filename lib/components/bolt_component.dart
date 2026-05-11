import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'hole_component.dart';
import '../game/screw_game.dart';

class BoltComponent extends BodyComponent<ScrewPuzzleGame>
    with TapCallbacks
    implements PositionProvider, ScaleProvider, AngleProvider {
  final double radius;
  final Vector2 initialPosition;
  bool isRusty;
  int hitsRemaining;
  HoleComponent? previousHole;

  BoltComponent({
    required this.initialPosition,
    this.radius = 0.40,
    this.isRusty = false,
  }) : hitsRemaining = isRusty ? 5 : 1,
       super(renderBody: false);

  void shake() {
    add(
      SequenceEffect([
        MoveByEffect(Vector2(0.05, 0), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 1)),
        MoveByEffect(Vector2(-0.05, 0), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 1)),
      ])
    );
  }

  bool _isLifted = false;
  bool get isLifted => _isLifted;
  set isLifted(bool value) {
    _isLifted = value;
    priority = value ? 100 : 3;

    // Safely remove existing effects to prevent concurrent modification or overlap
    children.whereType<ScaleEffect>().toList().forEach((e) => e.removeFromParent());
    children.whereType<RotateEffect>().toList().forEach((e) => e.removeFromParent());

    if (value) {
      add(
        ScaleEffect.to(
          Vector2.all(1.1),
          EffectController(duration: 0.3, reverseDuration: 0.3, infinite: true),
        ),
      );
      // Spin once when lifted
      add(
        RotateEffect.by(
          pi * 2, 
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
    } else {
      scale = Vector2.all(1.0);
    }
  }

  void _updateCollision(bool canCollide) {
    if (body.fixtures.isNotEmpty) {
      final filter = body.fixtures.first.filterData;
      filter.maskBits = canCollide ? ScrewPuzzleGame.kPlateCategory : 0x0000;
      body.fixtures.first.filterData = filter;
    }
  }

  @override
  Vector2 get position => body.position;

  @override
  set position(Vector2 val) => body.setTransform(val, body.angle);

  @override
  double get angle => body.angle;

  @override
  set angle(double value) => body.setTransform(body.position, value);

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

  final PositionComponent _visualOffset = PositionComponent();

  @override
  void render(Canvas canvas) {
    canvas.save();
    // Shift the rendering by our animated offset
    canvas.translate(_visualOffset.x, _visualOffset.y);
    _drawBolt(canvas);
    canvas.restore();
  }

  void _drawBolt(Canvas canvas) {
    // SCALE & SHADOW CALCULATION
    final scaleFactor = (isLifted ? 1.3 : 1.0) * scale.x;
    final blurIntensity = isLifted ? 0.2 : 0.08;

    // FIX: Shadow offset that stays fixed in world space even when bolt spins
    final worldOffset = isLifted ? Vector2(0.2, 0.4) : Vector2(0.05, 0.1);
    final localOffset = worldOffset..rotate(-body.angle);
    final shadowOffset = Offset(localOffset.x, localOffset.y);

    // Dynamic Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isLifted ? 0.6 : 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurIntensity);

    canvas.drawCircle(shadowOffset, radius, shadowPaint);

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    // Metallic Head (Polished Chrome / Rusty Steel)
    final progress = isRusty ? (hitsRemaining / 5.0) : 0.0;
    
    final rustColors = [
      const Color(0xFFD35400),
      const Color(0xFF8E44AD),
      const Color(0xFF3E2723),
    ];
    final cleanColors = [
      const Color(0xFFFFEB3B), // Bright Yellow
      const Color(0xFFFBC02D), // Deep Yellow
      const Color(0xFFF9A825), // Golden Amber
    ];

    final currentColors = List.generate(3, (i) => Color.lerp(cleanColors[i], rustColors[i], progress)!);

    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: currentColors,
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);

    canvas.save();
    canvas.scale(scaleFactor);

    // 1. Base Shape
    canvas.drawCircle(Offset.zero, radius, headPaint);

    // Add some "rust texture" if rusty
    if (isRusty) {
      final progress = hitsRemaining / 5.0;
      final rustTexturePaint = Paint()
        ..color = Colors.black.withOpacity(0.3 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.03
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.02);
      
      // Draw concentric rings that fade
      canvas.drawCircle(Offset.zero, radius * 0.7, rustTexturePaint);
      canvas.drawCircle(Offset.zero, radius * 0.4, rustTexturePaint);

      // Draw random "cracks" as the bolt is hit
      if (hitsRemaining < 5) {
        final crackPaint = Paint()
          ..color = Colors.black.withOpacity(0.4 * (1 - progress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.02;
        
        final random = Random(42);
        for (var i = 0; i < (5 - hitsRemaining) * 3; i++) {
          final angle = random.nextDouble() * pi * 2;
          final r1 = random.nextDouble() * radius;
          final r2 = r1 + 0.2;
          canvas.drawLine(
            Offset(cos(angle) * r1, sin(angle) * r1),
            Offset(cos(angle + 0.2) * r2, sin(angle + 0.2) * r2),
            crackPaint,
          );
        }
      }
    }

    // 2. Beveled Rim (Highlight edge)
    final rimHighlight = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
    canvas.drawCircle(Offset.zero, radius * 0.95, rimHighlight);

    // 3. Realistic Slot (Phillips '+' or Torx '*')
    final isTorx = (initialPosition.x.toInt() + initialPosition.y.toInt()) % 5 == 0; // Pseudo-random 1 in 5 is Torx

    final slotPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.black, const Color(0xFF2C3E50)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTorx ? 0.08 : 0.12
      ..strokeCap = StrokeCap.round;

    final shadowSlotPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTorx ? 0.10 : 0.14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.02);

    if (isLifted) {
      canvas.rotate(0.35);
    }

    void drawPhillips(Paint p) {
      canvas.drawLine(Offset(-radius * 0.4, 0), Offset(radius * 0.4, 0), p);
      canvas.drawLine(Offset(0, -radius * 0.4), Offset(0, radius * 0.4), p);
    }

    void drawTorx(Paint p) {
      // 6-point star (Torx)
      for (var i = 0; i < 3; i++) {
        final angle = i * (pi / 3);
        canvas.drawLine(
          Offset(cos(angle) * -radius * 0.4, sin(angle) * -radius * 0.4),
          Offset(cos(angle) * radius * 0.4, sin(angle) * radius * 0.4),
          p,
        );
      }
      // Inner hollow circle for security torx look
      canvas.drawCircle(Offset.zero, radius * 0.15, p..style = PaintingStyle.fill);
    }

    if (isTorx) {
      drawTorx(shadowSlotPaint);
      drawTorx(slotPaint);
    } else {
      drawPhillips(shadowSlotPaint); // First draw shadow
      drawPhillips(slotPaint);       // Then draw main slot
    }

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
      ..friction = 0.7 // Balanced grip for both impact and resting
      ..restitution = 0.0
      ..filter.categoryBits = ScrewPuzzleGame.kBoltHoleCategory
      ..filter.maskBits = ScrewPuzzleGame.kPlateCategory; // Solid by default

    return world.createBody(bodyDef)
      ..createFixture(fixtureDef)
      ..isBullet = true;
  }

  @override
  bool containsLocalPoint(Vector2 point) => point.length <= radius * 1.5;

  @override
  void onTapDown(TapDownEvent event) {
    game.onBoltTapped(this);
  }

  void moveTo(Vector2 target, {VoidCallback? onComplete}) {
    isLifted = true;
    _updateCollision(false);

    // Calculate the total distance we need to visually travel from our CURRENT physics body
    final targetOffset = target - body.position;

    // Reset visual offset to zero (start)
    _visualOffset.position = Vector2.zero();
    
    // Ensure the visual offset component is added
    if (_visualOffset.parent == null) add(_visualOffset);

    // Animate the visual offset from (0,0) to the target hole
    _visualOffset.add(
      MoveToEffect(
        targetOffset,
        EffectController(duration: 0.35, curve: Curves.easeInOutCubic),
        onComplete: () {
          // SEAMLESS HANDOVER:
          // 1. Teleport the physics body to the target hole
          // Keep the current rotation to avoid snapping
          body.setTransform(target, body.angle);
          
          // 2. Reset the visual offset to zero
          _visualOffset.position = Vector2.zero();
          
          // 3. Finalize
          _updateCollision(true);
          isLifted = false;
          if (onComplete != null) onComplete();
        },
      ),
    );
  }
}
