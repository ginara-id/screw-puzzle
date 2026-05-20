import 'dart:ui';
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
  int _hitsRemaining;
  int get hitsRemaining => _hitsRemaining;
  set hitsRemaining(int value) {
    if (_hitsRemaining == value) return;
    _hitsRemaining = value;
    _buildCachedBolt(); // Re-record visual state to GPU on damage taken
  }
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
  Path? _cachedCrackPath; // Cached procedurally generated rust cracks

  // Pre-cached Blur Filters for zero-allocation shadow runtime
  static final _blurLifted = MaskFilter.blur(BlurStyle.normal, 0.2);
  static final _blurNormal = MaskFilter.blur(BlurStyle.normal, 0.08);

  Picture? _cachedBoltPicture; // Hardened hardware cache

  BoltComponent({
    required this.initialPosition,
    this.radius = 0.40,
    this.isRusty = false,
  }) : _hitsRemaining = isRusty ? 6 : 1,
       super(renderBody: false);

  void shake() {
    if (_visualOffset.parent == null) add(_visualOffset);
    // Remove any running shake effects on _visualOffset to prevent conflicts
    _visualOffset.children.whereType<Effect>().forEach((e) => e.removeFromParent());
    _visualOffset.add(
      SequenceEffect([
        MoveByEffect(
          Vector2(0.06, 0.0),
          EffectController(
            duration: 0.03,
            reverseDuration: 0.03,
            repeatCount: 1,
            curve: Curves.easeOut,
          ),
        ),
        MoveByEffect(
          Vector2(-0.06, 0.0),
          EffectController(
            duration: 0.03,
            reverseDuration: 0.03,
            repeatCount: 1,
            curve: Curves.easeOut,
          ),
        ),
        MoveByEffect(
          Vector2(0.03, 0.0),
          EffectController(
            duration: 0.02,
            reverseDuration: 0.02,
            repeatCount: 1,
            curve: Curves.easeOut,
          ),
        ),
        MoveByEffect(
          Vector2(-0.03, 0.0),
          EffectController(
            duration: 0.02,
            reverseDuration: 0.02,
            repeatCount: 1,
            curve: Curves.easeOut,
          ),
        ),
      ]),
    );
  }

  bool _isLifted = false;
  bool get isLifted => _isLifted;
  set isLifted(bool value) {
    _isLifted = value;
    priority = value ? 100 : 3;

    // Removed high-intensity scale loops and rotations to satisfy User design request for 'clean/normal' feel.
    // Visual feedback is handled elegantly and instantly inside the high-performance render call.
    if (!value) {
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
    _buildCachedBolt(); // Record initial visual footprint
  }

  final PositionComponent _visualOffset = PositionComponent();

  @override
  void _buildCachedBolt() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    // 1. PRE-RENDER GRADIENTS & CRACKS
    final int currentStateHash = (isRusty ? 1000 : 0) + hitsRemaining;
    
    // Forces shader refresh logic
    final progress = isRusty ? (hitsRemaining / 6.0) : 0.0;
    final rustColors = [
      const Color(0xFFD35400),
      const Color(0xFF8E44AD),
      const Color(0xFF3E2723),
    ];
    final cleanColors = [
      const Color(0xFFFFEB3B),
      const Color(0xFFFBC02D),
      const Color(0xFFF9A825),
    ];

    final colors = [
      Color.lerp(cleanColors[0], rustColors[0], progress)!,
      Color.lerp(cleanColors[1], rustColors[1], progress)!,
      Color.lerp(cleanColors[2], rustColors[2], progress)!,
    ];

    final headShader = RadialGradient(
      center: const Alignment(-0.4, -0.4),
      colors: colors,
      stops: const [0.0, 0.4, 1.0],
    ).createShader(rect);

    _cachedSlotShader ??= LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.black, const Color(0xFF2C3E50)],
    ).createShader(rect);

    Path? crackPath;
    if (isRusty && hitsRemaining < 6) {
      final newPath = Path();
      final fixedSeed = initialPosition.x.toInt() ^ initialPosition.y.toInt();
      final staticRandom = Random(fixedSeed);
      for (var i = 0; i < (6 - hitsRemaining) * 3; i++) {
        final double angle = staticRandom.nextDouble() * pi * 2;
        final double r1 = staticRandom.nextDouble() * radius;
        final double r2 = r1 + 0.2;
        newPath.moveTo(cos(angle) * r1, sin(angle) * r1);
        newPath.lineTo(cos(angle + 0.2) * r2, sin(angle + 0.2) * r2);
      }
      crackPath = newPath;
    }

    // 2. DRAW STATIC HEAD & RUST
    _headPaint.shader = headShader;
    canvas.drawCircle(Offset.zero, radius, _headPaint);

    if (isRusty) {
      canvas.drawCircle(
        Offset.zero,
        radius * 0.7,
        _rustTexturePaint..color = Colors.black.withOpacity(0.3 * progress),
      );
      canvas.drawCircle(Offset.zero, radius * 0.4, _rustTexturePaint);
      if (crackPath != null) {
        _crackPaint.color = Colors.black.withOpacity(0.4 * (1 - progress));
        canvas.drawPath(crackPath, _crackPaint);
      }
    }

    // 3. BEVEL & SLOTS
    canvas.drawCircle(Offset.zero, radius * 0.95, _rimHighlight);

    final isTorx = (initialPosition.x.toInt() + initialPosition.y.toInt()) % 5 == 0;
    _slotPaint.shader = _cachedSlotShader;
    _slotPaint.strokeWidth = isTorx ? 0.08 : 0.12;
    _shadowSlotPaint.color = Colors.black.withOpacity(0.5);
    _shadowSlotPaint.strokeWidth = isTorx ? 0.10 : 0.14;

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
      p.style = PaintingStyle.stroke;
    }

    if (isTorx) {
      drawTorx(_shadowSlotPaint);
      drawTorx(_slotPaint);
    } else {
      drawPhillips(_shadowSlotPaint);
      drawPhillips(_slotPaint);
    }

    // 4. FINALIZE CACHE
    _cachedBoltPicture?.dispose();
    _cachedBoltPicture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(_visualOffset.x, _visualOffset.y);
    _drawBolt(canvas);
    canvas.restore();
  }

  void _drawBolt(Canvas canvas) {
    // A. DYNAMIC SHADOW - Must update based on active orientation relative to light source
    final scaleFactor = (isLifted ? 1.15 : 1.0) * scale.x; // Tuned down from 1.3 for subtle pop
    final worldOffset = isLifted ? Vector2(0.15, 0.25) : Vector2(0.05, 0.1);
    final localOffset = worldOffset..rotate(-body.angle);
    final shadowOffset = Offset(localOffset.x, localOffset.y);

    _shadowPaint
      ..color = Colors.black.withOpacity(isLifted ? 0.5 : 0.5)
      ..maskFilter = isLifted ? _blurLifted : _blurNormal;

    canvas.drawCircle(shadowOffset, radius, _shadowPaint);

    // B. GOD-TIER CACHE BLAST - Blasts static geometry straight to hardware
    canvas.save();
    canvas.scale(scaleFactor);
    // User explicitly demanded 'Normal' feel without heavy spinning/locking logic.
    // Automatic visual skew rotation removed.
    
    if (_cachedBoltPicture != null) {
      canvas.drawPicture(_cachedBoltPicture!);
    }
    canvas.restore();
  }

  @override
  void onRemove() {
    _cachedBoltPicture?.dispose();
    super.onRemove();
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
      ..friction =
          0.7 // Balanced grip for both impact and resting
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

  void moveTo(Vector2 target, Vector2 source, {VoidCallback? onComplete}) {
    isLifted = true;
    _updateCollision(false);

    // Since the physics body is already teleported to target immediately,
    // the visual offset begins at (source - target) and animates to zero (which represents the target).
    final targetOffset = source - target;

    // Reset visual offset to start position
    _visualOffset.position = targetOffset;

    // Ensure the visual offset component is added
    if (_visualOffset.parent == null) add(_visualOffset);

    // Clear any previous animations on _visualOffset
    _visualOffset.children.whereType<Effect>().forEach((e) => e.removeFromParent());

    // Animate the visual offset from targetOffset to (0,0) (which is the target hole)
    _visualOffset.add(
      MoveToEffect(
        Vector2.zero(),
        EffectController(duration: 0.25, curve: Curves.easeOutQuad),
        onComplete: () {
          // Reset the visual offset to zero just to be completely safe
          _visualOffset.position = Vector2.zero();

          _updateCollision(true);
          isLifted = false;
          if (onComplete != null) onComplete();
        },
      ),
    );
  }

  void cureRust() {
    if (!isRusty) return;
    isRusty = false;
    hitsRemaining = 1; // Setting trigger built-in cache regeneration automatically
    _buildCachedBolt(); // Force flush just in case
  }
}
