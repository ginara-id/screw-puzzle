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
  bool isAdLocked;
  bool isTargetHighlight = false;
  double _pulseTime = 0.0;
  double _errorFlashTimer = 0.0;

  Vector2 _scale = Vector2.all(1.0);
  @override
  Vector2 get scale => _scale;
  @override
  set scale(Vector2 value) => _scale = value;

  HoleComponent({
    required this.initialPosition,
    this.radius = 0.40,
    this.isOccupied = false,
    this.isAdLocked = false,
  }) : super(renderBody: false);

  @override
  void update(double dt) {
    super.update(dt);
    if (isTargetHighlight) {
      _pulseTime += dt * 5; // Pulse speed
    }
    if (_errorFlashTimer > 0) {
      _errorFlashTimer -= dt;
      if (_errorFlashTimer < 0) {
        _errorFlashTimer = 0.0;
      }
    }
  }

  void flashError() {
    _errorFlashTimer = 0.4; // 0.4 seconds flash
    
    // Scale squeeze & bounce effect using Flame standard ScaleEffect
    children.whereType<ScaleEffect>().forEach((e) => e.removeFromParent());
    add(
      ScaleEffect.to(
        Vector2.all(0.82),
        EffectController(
          duration: 0.06,
          reverseDuration: 0.12,
          curve: Curves.easeOutBack,
        ),
      ),
    );
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

  // OPTIMIZATION: Static cached paints to prevent Garbage Collector thrashing
  static final _holeBasePaint = Paint()..color = const Color(0xFF111111);
  static final _depthBasePaint = Paint()
    ..color = Colors.black.withOpacity(0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.1;
  static final _rimBasePaint = Paint()
    ..color = Colors.white.withOpacity(0.1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.05;
  static final _lockBgPaint = Paint()..color = Colors.black.withOpacity(0.65);
  static final _btnShadowPaint = Paint()..color = Colors.black.withOpacity(0.5);
  
  static final _errorGlowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.15);
  static final _errorStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.06;
  
  // Caching dynamically generated objects
  Shader? _btnShader;
  Shader? _glassShader;
  TextPainter? _cachedIconPainter;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(scale.x);

    // 1. Inner Dark Hole - Using cached static paint
    canvas.drawCircle(Offset.zero, radius, _holeBasePaint);

    // 2. Inner Shadow (Depth)
    canvas.drawCircle(Offset.zero, radius - 0.02, _depthBasePaint);

    // 3. Metallic Rim
    canvas.drawCircle(Offset.zero, radius, _rimBasePaint);

    // 3b. Glowing Red Error Flash Aura (optimized)
    if (_errorFlashTimer > 0) {
      final alpha = (_errorFlashTimer / 0.4 * 200).toInt().clamp(0, 255);
      _errorGlowPaint.color = Color.fromARGB(alpha, 229, 57, 53); // Red glow
      canvas.drawCircle(Offset.zero, radius * 1.15, _errorGlowPaint);

      _errorStrokePaint.color = Color.fromARGB((alpha * 1.2).toInt().clamp(0, 255), 255, 110, 110); // Red stroke
      canvas.drawCircle(Offset.zero, radius * 0.95, _errorStrokePaint);
    }

    // 4. Target Highlight Glow (Only when active and not occupied)
    if (isTargetHighlight && !isOccupied && !isAdLocked) {
      final pulseAlpha = ((math.sin(_pulseTime) + 1.0) / 2.0 * 150).toInt();
      
      // Still efficient as temporary assignment, consider static cache if needed later
      final glowPaint = Paint()
        ..color = Color.fromARGB(pulseAlpha, 255, 255, 255)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2);
      canvas.drawCircle(Offset.zero, radius * 0.8, glowPaint);

      final strokeGlowPaint = Paint()
        ..color = Color.fromARGB(pulseAlpha + 50, 255, 215, 0) 
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05;
      canvas.drawCircle(Offset.zero, radius * 0.9, strokeGlowPaint);
    }

    // 5. Ad Lock Overlay (HEAVY OPTIMIZATION APPLIED)
    if (isAdLocked) {
      canvas.drawCircle(Offset.zero, radius, _lockBgPaint);
      canvas.drawCircle(const Offset(0.05, 0.08), radius * 0.7, _btnShadowPaint);

      // Build Shaders only ONCE ever per component instance
      _btnShader ??= const RadialGradient(
        colors: [Color(0xFFFFD54F), Color(0xFFF57F17)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 0.7));
      
      _glassShader ??= LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 0.7));

      canvas.drawCircle(Offset.zero, radius * 0.7, Paint()..shader = _btnShader);
      canvas.drawCircle(Offset.zero, radius * 0.7, Paint()..shader = _glassShader);

      // ABSOLUTE CULPRIT FOUND AND TERMINATED HERE:
      // Never recreate or call layout() on a TextPainter in render loop!
      if (_cachedIconPainter == null) {
        _cachedIconPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(Icons.play_arrow_rounded.codePoint),
            style: TextStyle(
              fontSize: radius * 1.2,
              fontFamily: Icons.play_arrow_rounded.fontFamily,
              package: Icons.play_arrow_rounded.fontPackage,
              color: Colors.white,
              shadows: const [
                Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 1),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        // Perform expensive text metrics layout EXACTLY ONCE in object lifetime
        _cachedIconPainter!.layout();
      }

      // Super fast hardware blit drawing
      _cachedIconPainter!.paint(
        canvas,
        Offset(-_cachedIconPainter!.width / 2, -_cachedIconPainter!.height / 2),
      );
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
