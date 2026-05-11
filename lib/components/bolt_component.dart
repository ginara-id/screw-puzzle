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

  // CACHED PAINTS & SHADERS: Prevents creation of objects during the render loop
  late final Paint _shadowPaint = Paint();
  late final Paint _headPaint = Paint();
  late final Paint _rustTexturePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.03
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.02);
  late final Paint _crackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
  late final Paint _rimHighlight = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
  late final Paint _slotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
  late final Paint _shadowSlotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.02);

  Shader? _cachedHeadShader;
  Shader? _cachedSlotShader;
  int? _lastHashState; // Detects changes to invalidate shader

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
    // 1. Optimize Shadow Calculation: Directly set reuseable paint state
    final scaleFactor = (isLifted ? 1.3 : 1.0) * scale.x;
    final blurIntensity = isLifted ? 0.2 : 0.08;

    final worldOffset = isLifted ? Vector2(0.2, 0.4) : Vector2(0.05, 0.1);
    final localOffset = worldOffset..rotate(-body.angle);
    final shadowOffset = Offset(localOffset.x, localOffset.y);

    // Configure reusable shadow paint
    _shadowPaint
      ..color = Colors.black.withOpacity(isLifted ? 0.6 : 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurIntensity);

    canvas.drawCircle(shadowOffset, radius, _shadowPaint);

    // 2. Pre-allocate constant drawing rect for shaders
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    // SMART SHADER CACHE: Check hash to see if rusty progression changed
    final int currentStateHash = (isRusty ? 1000 : 0) + hitsRemaining;
    
    if (_cachedHeadShader == null || _lastHashState != currentStateHash) {
      _lastHashState = currentStateHash;
      
      final progress = isRusty ? (hitsRemaining / 5.0) : 0.0;
      final rustColors = [const Color(0xFFD35400), const Color(0xFF8E44AD), const Color(0xFF3E2723)];
      final cleanColors = [const Color(0xFFFFEB3B), const Color(0xFFFBC02D), const Color(0xFFF9A825)];
      
      // Manual lerp to avoid List.generate dynamic lists memory footprint
      final colors = [
        Color.lerp(cleanColors[0], rustColors[0], progress)!,
        Color.lerp(cleanColors[1], rustColors[1], progress)!,
        Color.lerp(cleanColors[2], rustColors[2], progress)!,
      ];

      _cachedHeadShader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: colors,
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);

      // Slot Shader Cache
      _cachedSlotShader ??= LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.black, const Color(0xFF2C3E50)],
      ).createShader(rect);
    }

    _headPaint.shader = _cachedHeadShader;

    canvas.save();
    canvas.scale(scaleFactor);

    // Draw Metal Head
    canvas.drawCircle(Offset.zero, radius, _headPaint);

    // 3. Rust Layer optimization
    if (isRusty) {
      final progress = hitsRemaining / 5.0;
      canvas.drawCircle(Offset.zero, radius * 0.7, _rustTexturePaint..color = Colors.black.withOpacity(0.3 * progress));
      canvas.drawCircle(Offset.zero, radius * 0.4, _rustTexturePaint);

      if (hitsRemaining < 5) {
        // Draw cracks without recreating Random seed generators and complex logic inside rendering loop
        _crackPaint.color = Colors.black.withOpacity(0.4 * (1 - progress));
        
        // Seed fixed once based on position so it does not re-randomize and dance every frame causing redraw stress
        final fixedSeed = initialPosition.x.toInt() ^ initialPosition.y.toInt();
        final staticRandom = Random(fixedSeed);
        for (var i = 0; i < (5 - hitsRemaining) * 3; i++) {
          final angle = staticRandom.nextDouble() * pi * 2;
          final r1 = staticRandom.nextDouble() * radius;
          final r2 = r1 + 0.2;
          canvas.drawLine(
            Offset(cos(angle) * r1, sin(angle) * r1),
            Offset(cos(angle + 0.2) * r2, sin(angle + 0.2) * r2),
            _crackPaint,
          );
        }
      }
    }

    // 4. Beveled Highlight
    canvas.drawCircle(Offset.zero, radius * 0.95, _rimHighlight);

    // 5. Slot Painting Optimization
    final isTorx = (initialPosition.x.toInt() + initialPosition.y.toInt()) % 5 == 0;
    
    _slotPaint.shader = _cachedSlotShader;
    _slotPaint.strokeWidth = isTorx ? 0.08 : 0.12;
    _shadowSlotPaint.color = Colors.black.withOpacity(0.5);
    _shadowSlotPaint.strokeWidth = isTorx ? 0.10 : 0.14;

    if (isLifted) {
      canvas.rotate(0.35);
    }

    void drawPhillips(Paint p) {
      canvas.drawLine(Offset(-radius * 0.4, 0), Offset(radius * 0.4, 0), p);
      canvas.drawLine(Offset(0, -radius * 0.4), Offset(0, radius * 0.4), p);
    }

    void drawTorx(Paint p) {
      for (var i = 0; i < 3; i++) {
        final angle = i * (pi / 3);
        canvas.drawLine(
          Offset(cos(angle) * -radius * 0.4, sin(angle) * -radius * 0.4),
          Offset(cos(angle) * radius * 0.4, sin(angle) * radius * 0.4),
          p,
        );
      }
      canvas.drawCircle(Offset.zero, radius * 0.15, p..style = PaintingStyle.fill);
      p.style = PaintingStyle.stroke; // restore after fill
    }

    if (isTorx) {
      drawTorx(_shadowSlotPaint);
      drawTorx(_slotPaint);
    } else {
      drawPhillips(_shadowSlotPaint);
      drawPhillips(_slotPaint);
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
