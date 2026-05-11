import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/screw_game.dart';

class TimerTextComponent extends PositionComponent with HasGameRef<ScrewPuzzleGame> {
  late final TextComponent _textComponent;
  
  // PRE-CACHED PAINTS: Prevents per-frame Object construction in UI thread
  late final TextPaint _normalPaint;
  late final TextPaint _emergencyPaint;
  
  String _lastText = "";
  bool _wasEmergency = false;

  // Set an extremely high priority so it's never obstructed
  TimerTextComponent() : super(priority: 9999);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Cache both paint objects ONCE rather than allocating per frame!
    _normalPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFF00FF41), // Matrix/Industrial Green
        fontSize: 28,
        fontWeight: FontWeight.w900,
        fontFamily: 'Courier New',
        letterSpacing: 2.0,
        shadows: [Shadow(color: Color(0xFF00FF41), blurRadius: 10)],
      ),
    );

    _emergencyPaint = TextPaint(
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
    
    size = Vector2(140, 50);
    position = Vector2(gameRef.canvasSize.x / 2, 60);
    anchor = Anchor.center;

    add(RectangleComponent(
      size: size,
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF95A5A6), const Color(0xFF34495E)],
        ).createShader(size.toRect()),
    ));

    final innerSize = size - Vector2.all(8);
    add(RectangleComponent(
      size: innerSize,
      position: Vector2.all(4),
      paint: Paint()
        ..color = const Color(0xFF0A0A0A)
        ..style = PaintingStyle.fill,
    ));

    _textComponent = TextComponent(
      text: '00:00',
      anchor: Anchor.center,
      position: size / 2, 
      textRenderer: _normalPaint,
    );
    add(_textComponent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    final time = gameRef.remainingTime;
    final minutes = (time / 60).floor();
    final seconds = (time % 60).floor().clamp(0, 59);
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    final currentText = '$mStr:$sStr';
    
    // 1. ONLY update text geometry if numeric value changed (reduces allocation by 60x)
    if (_lastText != currentText) {
      _textComponent.text = currentText;
      _lastText = currentText;
    }

    final bool isEmergency = (time < 10 && time > 0);
    
    // 2. Emergency Pulsing is okay as it uses double math, not object allocation
    if (isEmergency) {
      _textComponent.scale = Vector2.all(1.0 + (0.05 * (time * 4).toInt() % 2));
    }

    // 3. ONLY swap renderers IF the state transition boundary is crossed
    if (isEmergency != _wasEmergency) {
      _wasEmergency = isEmergency;
      _textComponent.textRenderer = isEmergency ? _emergencyPaint : _normalPaint;
      if (!isEmergency) {
        _textComponent.scale = Vector2.all(1.0);
      }
    }
  }
}
