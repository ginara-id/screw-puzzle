import 'package:flutter/material.dart';
import '../game/screw_game.dart';

class LevelMapOverlay extends StatelessWidget {
  final ScrewPuzzleGame game;

  const LevelMapOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(begin: const Offset(0, -2), end: Offset.zero),
        duration: const Duration(milliseconds: 700),
        curve: Curves.bounceOut,
        builder: (context, offset, child) {
          return FractionalTranslation(
            translation: offset,
            child: child,
          );
        },
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF111111), width: 8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.9), blurRadius: 40, spreadRadius: 10),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildRivets(),
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF111111), width: 4)),
                      color: Color(0xFF222222),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "SYSTEM OVERRIDE",
                          style: TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                            fontFamily: 'Courier',
                            shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2))],
                          ),
                        ),
                        IconButton(
                          onPressed: () => game.overlays.remove('LevelMap'),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFFF9800), size: 32),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        final level = index + 1;
                        return _buildLevelButton(context, level);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelButton(BuildContext context, int level) {
    final bool isUnlocked = level <= (game.currentLevel + 1); 
    final bool isCurrent = level == game.currentLevel;

    return GestureDetector(
      onTap: isUnlocked ? () {
        game.currentLevel = level;
        game.resetLevel();
        game.overlays.remove('LevelMap');
        game.overlays.remove('MainMenu');
        if (!game.overlays.isActive('HUD')) {
          game.overlays.add('HUD');
        }
      } : null,
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked 
              ? (isCurrent ? const Color(0xFF4A4A4A) : const Color(0xFF333333))
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isCurrent ? const Color(0xFFFF9800) : const Color(0xFF111111),
            width: isCurrent ? 4 : 3,
          ),
          boxShadow: isUnlocked ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 4,
              offset: const Offset(2, 4),
            ),
            if (isCurrent)
              BoxShadow(
                color: const Color(0xFFFF9800).withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              )
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.9),
              blurRadius: 2,
              offset: const Offset(1, 2),
            )
          ],
        ),
        child: Center(
          child: isUnlocked
              ? Text(
                  level.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: isCurrent ? const Color(0xFFFF9800) : const Color(0xFF9E9E9E),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Courier',
                    letterSpacing: 2.0,
                    shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: const Offset(2, 2))],
                  ),
                )
              : const Icon(Icons.lock_rounded, color: Color(0xFF424242), size: 32),
        ),
      ),
    );
  }

  Widget _buildRivets() {
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -24, left: -24, child: _rivet()),
          Positioned(top: -24, right: -24, child: _rivet()),
          Positioned(bottom: -24, left: -24, child: _rivet()),
          Positioned(bottom: -24, right: -24, child: _rivet()),
        ],
      ),
    );
  }

  Widget _rivet() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFF777777),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.white30, blurRadius: 1, offset: Offset(-1, -1)),
        ],
      ),
    );
  }
}

