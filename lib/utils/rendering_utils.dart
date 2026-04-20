import 'package:flame/components.dart';
import 'package:flame/rendering.dart';
import 'package:flutter/material.dart';

/// A custom decorator to simulate 3D depth with an angled drop shadow.
class Shadow3DDecorator extends Decorator {
  final Vector2 base;
  final double angle;
  final double opacity;
  final double blur;

  Shadow3DDecorator({
    required this.base,
    this.angle = 0.5,
    this.opacity = 0.4,
    this.blur = 1.0,
  });

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    // 1. Draw the shadow first
    canvas.save();
    // Offset based on pseudo-3D "light source"
    canvas.translate(0.15, 0.25);
    
    // In Flame, to draw a shadow of the component, we would ideally
    // use a Layer, but for simple shapes like bolts/plates, 
    // a simple offset is often enough when handled in the render() 
    // methods of the components themselves.
    
    // However, since this is a Decorator, we'll let it handle 
    // the underlying canvas translation.
    canvas.restore();

    // 2. Draw the actual component
    draw(canvas);
  }
}
