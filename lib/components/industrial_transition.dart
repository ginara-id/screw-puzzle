import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' hide Image, Picture;
import 'dart:math';
import '../game/screw_game.dart';

enum TransitionMode {
  none,
  closeAndOpen,
  closeOnly,
  openOnly,
}

class IndustrialTransitionComponent extends PositionComponent with HasGameRef<ScrewPuzzleGame> {
  final Future<void> Function() onHalfway;
  final TransitionMode mode;

  IndustrialTransitionComponent({
    required this.onHalfway,
    this.mode = TransitionMode.closeAndOpen,
  }) : super(priority: 1000000); // Massive priority to be above everything

  bool _hadHud = false;
  late final _Door leftDoor;
  late final _Door rightDoor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (mode == TransitionMode.none) {
      await onHalfway();
      removeFromParent();
      return;
    }

    // Set size to cover full viewport
    size = gameRef.camera.viewport.size;
    position = Vector2.zero(); // Top-left of viewport

    // Hide HUD so transition is on top (overlays are always above components)
    _hadHud = gameRef.overlays.isActive('HUD');
    if (_hadHud) gameRef.overlays.remove('HUD');
    
    // Mute BGM so the gate mechanical sounds stand out
    gameRef.audio.muteBgmForTransition();

    final doorWidth = size.x / 2 + 10; // Extra overlap
    final doorHeight = size.y + 20;
    
    // Initial positions based on mode
    final startClosed = mode == TransitionMode.openOnly;

    leftDoor = _Door(
      size: Vector2(doorWidth, doorHeight),
      position: Vector2(startClosed ? doorWidth / 2 : -doorWidth / 2, doorHeight / 2),
      isLeft: true,
    );
    rightDoor = _Door(
      size: Vector2(doorWidth, doorHeight),
      position: Vector2(startClosed ? size.x - doorWidth / 2 : size.x + doorWidth / 2, doorHeight / 2),
      isLeft: false,
    );

    add(leftDoor);
    add(rightDoor);

    void finishTransition() {
      // Always restore HUD when a transition finishes (doors open),
      // unless we are in the Main Menu.
      if (!gameRef.overlays.isActive('MainMenu')) {
        gameRef.overlays.add('HUD');
        gameRef.audio.playGameBGM();
      } else {
        gameRef.audio.playMenuBGM();
      }
      removeFromParent();
    }

    if (mode == TransitionMode.openOnly) {
      // Just open
      await onHalfway();
      gameRef.audio.playGateOpen();
      leftDoor.add(MoveEffect.to(Vector2(-doorWidth / 2, doorHeight / 2), EffectController(duration: 0.6, curve: Curves.easeOutCubic)));
      rightDoor.add(MoveEffect.to(Vector2(size.x + doorWidth / 2, doorHeight / 2), EffectController(duration: 0.6, curve: Curves.easeOutCubic)));
      Future.delayed(const Duration(milliseconds: 700), finishTransition);
      return;
    }

    // Slam shut
    gameRef.audio.playGateClose();
    leftDoor.add(MoveEffect.to(Vector2(doorWidth / 2, doorHeight / 2), EffectController(duration: 0.4, curve: Curves.easeInCubic)));
    rightDoor.add(MoveEffect.to(Vector2(size.x - doorWidth / 2, doorHeight / 2), EffectController(duration: 0.4, curve: Curves.easeInCubic)));

    Future.delayed(const Duration(milliseconds: 450), () async {
      await onHalfway();
      
      // Camera shake
      final rnd = Random();
      gameRef.camera.viewfinder.add(
        MoveEffect.by(
          Vector2(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1),
          EffectController(duration: 0.05, alternate: true, repeatCount: 3),
        )
      );

      if (mode == TransitionMode.closeOnly) {
        // Just stay closed!
        return;
      }
      
      // Pause then open
      Future.delayed(const Duration(milliseconds: 600), () {
        gameRef.audio.playGateOpen();
        leftDoor.add(MoveEffect.to(Vector2(-doorWidth / 2, doorHeight / 2), EffectController(duration: 0.6, curve: Curves.easeOutCubic)));
        rightDoor.add(MoveEffect.to(Vector2(size.x + doorWidth / 2, doorHeight / 2), EffectController(duration: 0.6, curve: Curves.easeOutCubic)));
        Future.delayed(const Duration(milliseconds: 700), finishTransition);
      });
    });
  }
}

class _Door extends PositionComponent {
  final bool isLeft;
  Picture? _cachedPicture;

  _Door({required super.size, required super.position, required this.isLeft})
      : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _preRender();
  }

  void _preRender() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = size.toRect();

    // 1. Heavy iron metal paint
    final paint = Paint()..color = const Color(0xFF2A2A2A);
    canvas.drawRect(rect, paint);

    // 2. Inner shadows and highlights for massive metal plate feel
    final highlight = Paint()..color = Colors.white.withOpacity(0.1);
    final shadow = Paint()..color = Colors.black.withOpacity(0.6);
    final thick = 4.0;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, thick), highlight);
    canvas.drawRect(Rect.fromLTWH(0, size.y - thick, size.x, thick), shadow);

    if (isLeft) {
      canvas.drawRect(Rect.fromLTWH(0, 0, thick, size.y), highlight);
      canvas.drawRect(Rect.fromLTWH(size.x - thick * 2, 0, thick * 2, size.y), shadow);
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, thick * 2, size.y), highlight);
      canvas.drawRect(Rect.fromLTWH(size.x - thick, 0, thick, size.y), shadow);
    }

    // 3. Rust / Grime Overlay
    final grimePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
      ).createShader(rect);
    canvas.drawRect(rect, grimePaint);

    // 4. Warning Stripes
    final stripeWidth = 40.0;
    final stripeRect = isLeft
        ? Rect.fromLTWH(size.x - stripeWidth - thick * 2, 0, stripeWidth, size.y)
        : Rect.fromLTWH(thick * 2, 0, stripeWidth, size.y);

    final stripeBasePaint = Paint()..color = const Color(0xFFFF9800);
    canvas.drawRect(stripeRect, stripeBasePaint);

    final hazardPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(stripeRect);
    for (var i = -size.y; i < size.y * 2; i += 40.0) {
      final path = Path()
        ..moveTo(stripeRect.left, i)
        ..lineTo(stripeRect.right, i + 20.0)
        ..lineTo(stripeRect.right, i + 40.0)
        ..lineTo(stripeRect.left, i + 20.0)
        ..close();
      canvas.drawPath(path, hazardPaint);
    }
    canvas.restore();

    // 5. Heavy Rivets
    final rivetPaint = Paint()..color = const Color(0xFF555555);
    final rivetShadow = Paint()..color = Colors.black.withOpacity(0.8);
    final rivetHighlight = Paint()..color = Colors.white.withOpacity(0.3);

    final rivetX = isLeft ? size.x - stripeWidth - 30.0 : stripeWidth + 30.0;

    for (var y = 40.0; y < size.y; y += 80.0) {
      canvas.drawCircle(Offset(rivetX + 2, y + 2), 6.0, rivetShadow);
      canvas.drawCircle(Offset(rivetX, y), 6.0, rivetPaint);
      canvas.drawCircle(Offset(rivetX - 2, y - 2), 3.0, rivetHighlight);
    }

    // 6. Horizontal center seam
    final seamPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(0, size.y / 2), Offset(size.x, size.y / 2), seamPaint);
    canvas.drawLine(
        Offset(0, size.y / 2 + 3.0), Offset(size.x, size.y / 2 + 3.0), highlight..strokeWidth = 1.0);

    _cachedPicture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }
  }

  @override
  void onRemove() {
    _cachedPicture?.dispose();
    super.onRemove();
  }
}
