import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/screw_game.dart';

class TimerTextComponent extends PositionComponent with HasGameRef<ScrewPuzzleGame> {
  late final TextComponent _textComponent;
  
  // Set an extremely high priority so it's never obstructed
  TimerTextComponent() : super(priority: 9999);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Positioned safely at the TOP CENTER
    size = Vector2(140, 50);
    position = Vector2(gameRef.canvasSize.x / 2, 60);
    anchor = Anchor.center;

    // 1. Outer Metallic Frame
    add(RectangleComponent(
      size: size,
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF95A5A6), const Color(0xFF34495E)],
        ).createShader(size.toRect()),
    ));

    // 2. Inner Dark Glass Screen
    final innerSize = size - Vector2.all(8);
    add(RectangleComponent(
      size: innerSize,
      position: Vector2.all(4),
      paint: Paint()
        ..color = const Color(0xFF0A0A0A)
        ..style = PaintingStyle.fill,
    ));

    // 3. Digital Text
    _textComponent = TextComponent(
      text: '00:00',
      anchor: Anchor.center,
      position: size / 2, // Centered inside the frame
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF00FF41), // Matrix/Industrial Green
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontFamily: 'Courier New',
          letterSpacing: 2.0,
          shadows: [
            Shadow(color: Color(0xFF00FF41), blurRadius: 10),
          ],
        ),
      ),
    );
    add(_textComponent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    final time = gameRef.remainingTime;
    final minutes = (time / 60).floor();
    final seconds = (time % 60).floor();
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    
    _textComponent.text = '$mStr:$sStr';

    // Emergency State
    if (time < 10 && time > 0) {
      _textComponent.textRenderer = TextPaint(
        style: const TextStyle(
          color: Color(0xFFFF3333), // Bright Warning Red
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontFamily: 'Courier New',
          letterSpacing: 2.0,
          shadows: [
            Shadow(color: Color(0xFFFF3333), blurRadius: 15),
            Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 2),
          ],
        ),
      );
      // Gentle pulse on the text
      _textComponent.scale = Vector2.all(1.0 + (0.05 * (time * 4).toInt() % 2));
    } else {
      // Revert style if time bonus puts it back over 10
      _textComponent.scale = Vector2.all(1.0);
      _textComponent.textRenderer = TextPaint(
        style: const TextStyle(
          color: Color(0xFF00FF41),
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontFamily: 'Courier New',
          letterSpacing: 2.0,
          shadows: [Shadow(color: Color(0xFF00FF41), blurRadius: 10)],
        ),
      );
    }
  }
}
