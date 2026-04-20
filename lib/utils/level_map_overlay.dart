import 'package:flutter/material.dart';
import '../game/screw_game.dart';

class LevelMapOverlay extends StatelessWidget {
  final ScrewPuzzleGame game;

  const LevelMapOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Stack(
        children: [
          // Background Map
          Positioned.fill(
            child: Image.asset(
              'assets/images/workshop_map.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // Title
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                   Text(
                    "WORKSHOP BLUEPRINTS",
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))],
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(height: 2, width: 200, color: Colors.amber.shade700),
                ],
              ),
            ),
          ),

          // Level Nodes (Robot Parts)
          _buildMapNode(context, 1, "The Heart", 48, 42, Icons.favorite),
          _buildMapNode(context, 2, "Steam Lung", 38, 55, Icons.air),
          _buildMapNode(context, 3, "Piston Limb", 62, 48, Icons.settings_accessibility),
          _buildMapNode(context, 4, "Brass Joint", 32, 35, Icons.hub),
          _buildMapNode(context, 5, "Optic Sensor", 55, 18, Icons.visibility),
          _buildMapNode(context, 6, "Steam Valve", 28, 55, Icons.vibration),
          _buildMapNode(context, 7, "Cooling Pipe", 72, 62, Icons.shower),
          _buildMapNode(context, 8, "Gear Case", 42, 78, Icons.settings),
          _buildMapNode(context, 9, "Neural Cog", 48, 12, Icons.psychology),
          _buildMapNode(context, 10, "Final Core", 50, 32, Icons.token),

          // Close Button
          Positioned(
            bottom: 40,
            right: 40,
            child: FloatingActionButton.extended(
              onPressed: () => game.overlays.remove('LevelMap'),
              backgroundColor: const Color(0xFF2D1E12),
              icon: const Icon(Icons.close, color: Colors.amber),
              label: const Text("BACK TO WORKSHOP", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.amber, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapNode(BuildContext context, int level, String partName, double xPercent, double yPercent, IconData icon) {
    final bool isUnlocked = level <= (game.currentLevel + 1); // Progression unlock
    final bool isCurrent = level == game.currentLevel;

    return Positioned(
      left: MediaQuery.of(context).size.width * (xPercent / 100),
      top: MediaQuery.of(context).size.height * (yPercent / 100),
      child: GestureDetector(
        onTap: isUnlocked ? () {
          game.currentLevel = level;
          game.resetLevel();
          game.overlays.remove('LevelMap');
        } : null,
        child: Column(
          children: [
            Container(
              width: isCurrent ? 60 : 50,
              height: isCurrent ? 60 : 50,
              decoration: BoxDecoration(
                color: isUnlocked ? (isCurrent ? Colors.amber : const Color(0xFFB8860B)) : Colors.grey.shade900.withOpacity(0.8),
                border: Border.all(color: isCurrent ? Colors.white : Colors.amber.shade700, width: 3),
                borderRadius: BorderRadius.circular(8),
                boxShadow: isUnlocked ? [
                  BoxShadow(color: isCurrent ? Colors.amber : Colors.black, blurRadius: 10, spreadRadius: 2)
                ] : [],
              ),
              child: Icon(
                icon,
                color: isUnlocked ? (isCurrent ? Colors.black : Colors.white) : Colors.white24,
                size: 30,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                partName,
                style: TextStyle(
                  color: isUnlocked ? Colors.amber : Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

