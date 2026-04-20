import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../game/screw_game.dart';

class WinMenu extends StatelessWidget {
  final ScrewPuzzleGame game;
  const WinMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF5DEB3), // Aged Parchment
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB8860B), width: 8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CHAPTER COMPLETE!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2D1E12),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                  letterSpacing: 2,
                ),
              ),
              const Divider(color: Color(0xFFB8860B), thickness: 2),
              const SizedBox(height: 20),
              const Text(
                "The robot's systems are stabilizing. Silas nods in approval.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5D4037), fontSize: 14, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  game.overlays.remove('WinMenu');
                  game.nextLevel();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D1E12),
                  foregroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  side: const BorderSide(color: Colors.amber, width: 2),
                ),
                child: const Text(
                  'CONTINUE REPAIR',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class GameOverMenu extends StatelessWidget {
  final ScrewPuzzleGame game;
  const GameOverMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                game.overlays.remove('GameOverMenu');
                game.resetLevel();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class HUDMenu extends StatelessWidget {
  final ScrewPuzzleGame game;
  const HUDMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            // Left Side: Gauges
            Row(
              children: [
                _buildGauge(context, "LEVEL", game.currentLevel / 10.0, game.currentLevel.toString()),
              ],
            ),

            // Top Right: Controls
            Positioned(
              top: 0,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconButton(
                    icon: Icons.map,
                    label: "MAP",
                    onPressed: () => game.overlays.add('LevelMap'),
                  ),
                  const SizedBox(width: 15),
                  _buildIconButton(
                    icon: Icons.refresh,
                    label: "RESTART",
                    onPressed: () => game.resetLevel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.amber, size: 30),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF2D1E12),
            side: const BorderSide(color: Colors.amber, width: 2),
            padding: const EdgeInsets.all(10),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Widget _buildGauge(BuildContext context, String label, double value, String textValue) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: GaugePainter(value: value),
            child: Center(
              child: Text(
                textValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Courier',
                ),
              ),
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }
}

class GaugePainter extends CustomPainter {
  final double value; // 0.0 to 1.0

  GaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Brass Ring
    final ringPaint = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius - 3, ringPaint);

    // 2. Dial Face
    final facePaint = Paint()
      ..color = const Color(0xFF2D1E12);
    canvas.drawCircle(center, radius - 6, facePaint);

    // 3. Scale Marks
    final markPaint = Paint()
      ..color = Colors.amber.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i <= 10; i++) {
      final angle = -2.35 + (i * (4.7 / 10)); // From -135 to +135 degrees
      final start = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 12);
      final end = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 18);
      canvas.drawLine(start, end, markPaint);
    }

    // 4. Needle
    final needleAngle = -2.35 + (value * 4.7);
    final needlePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final needleEnd = center + Offset(math.cos(needleAngle), math.sin(needleAngle)) * (radius - 10);
    canvas.drawLine(center, needleEnd, needlePaint);

    // 5. Center Nut
    final nutPaint = Paint()..color = const Color(0xFFB8860B);
    canvas.drawCircle(center, 4, nutPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}




