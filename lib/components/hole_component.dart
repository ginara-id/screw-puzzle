import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'dart:math' as math;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../game/screw_game.dart';

class HoleComponent extends BodyComponent<ScrewPuzzleGame>
    with TapCallbacks
    implements ScaleProvider {
  final double radius;
  final Vector2 initialPosition;
  bool isOccupied;
  bool isTargetHighlight = false;
  double _pulseTime = 0.0;

  Vector2 _scale = Vector2.all(1.0);
  @override
  Vector2 get scale => _scale;
  @override
  set scale(Vector2 value) => _scale = value;

  HoleComponent({
    required this.initialPosition,
    this.radius = 0.40,
    this.isOccupied = false,
  }) : super(renderBody: false);

  @override
  void update(double dt) {
    super.update(dt);
    if (isTargetHighlight) {
      _pulseTime += dt * 5; // Pulse speed
    }
  }

  @override
  Vector2 get position => body.position;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Holes represent the deep targets in the board
    priority = 1;
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      type: BodyType.static,
    );

    // Sensor fixture to detect bolts if needed, though we use coordinate snapping
    final shape = CircleShape()..radius = radius;
    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..filter.categoryBits = ScrewPuzzleGame.kBoltHoleCategory
      ..filter.maskBits = 0x0000;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(scale.x);

    // 1. Inner Dark Hole (The deep background)
    final holePaint = Paint()..color = const Color(0xFF111111);
    canvas.drawCircle(Offset.zero, radius, holePaint);

    // 2. Inner Shadow (Depth) - Standardized with PlateComponent
    final depthPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1;
    canvas.drawCircle(Offset.zero, radius - 0.02, depthPaint);

    // 3. Metallic Rim - Standardized with PlateComponent
    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    canvas.drawCircle(Offset.zero, radius, rimPaint);

    // 4. Target Highlight Glow (Only when active and not occupied)
    if (isTargetHighlight && !isOccupied) {
      final pulseAlpha = ((math.sin(_pulseTime) + 1.0) / 2.0 * 150).toInt();
      final glowPaint = Paint()
        ..color = Color.fromARGB(pulseAlpha, 255, 255, 255)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2);
      canvas.drawCircle(Offset.zero, radius * 0.8, glowPaint);

      final strokeGlowPaint = Paint()
        ..color =
            Color.fromARGB(pulseAlpha + 50, 255, 215, 0) // Amber tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05;
      canvas.drawCircle(Offset.zero, radius * 0.9, strokeGlowPaint);
    }

    canvas.restore();
  }

  void playSnapSound() {
    // sound hook
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.onHoleTapped(this);
  }
}
