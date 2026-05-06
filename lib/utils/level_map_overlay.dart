import 'package:flutter/material.dart';
import '../game/screw_game.dart';

class LevelMapOverlay extends StatelessWidget {
  final ScrewPuzzleGame game;
  const LevelMapOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.9),
      child: Stack(
        children: [
          // 1. OUTERMOST FRAME (THE MACHINE CASING)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: _industrialFrameDecoration(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Background Texture (Gears & Pipes)
                    _buildBackgroundDecoration(),

                    // 2. HEADER AREA
                    _buildPremiumHeader(),

                    // 3. SCROLLABLE CONTENT
                    Positioned.fill(
                      top: 100,
                      bottom: 100,
                      child: _buildScrollableGrid(),
                    ),

                    // 4. FOOTER CONTROLS
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildPremiumFooter(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _industrialFrameDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB8860B), Color(0xFF3E2723), Color(0xFFB8860B)],
        stops: [0.0, 0.5, 1.0],
      ),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: const Color(0xFF2A1B14), width: 4),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 40, spreadRadius: 10),
        const BoxShadow(color: Colors.white10, blurRadius: 2, offset: Offset(-2, -2)),
      ],
    );
  }

  Widget _buildBackgroundDecoration() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.05,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1418),
            image: DecorationImage(
              image: NetworkImage('https://www.transparenttextures.com/patterns/carbon-fibre.png'),
              repeat: ImageRepeat.repeat,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: _headerDecoration(),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ENGINEERING SECTORS',
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'Courier',
              letterSpacing: 4,
              shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))],
            ),
          ),
          SizedBox(height: 5),
          Text(
            'HYDRAULIC-SYSTEM-STATUS: ONLINE',
            style: TextStyle(color: Colors.greenAccent, fontSize: 8, letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  BoxDecoration _headerDecoration() {
    return BoxDecoration(
      color: const Color(0xFF1B242C),
      border: const Border(bottom: BorderSide(color: Color(0xFF8B5E3C), width: 4)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
    );
  }

  Widget _buildScrollableGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 35,
        crossAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: 50,
      itemBuilder: (context, index) {
        final level = index + 1;
        final isUnlocked = level <= 12;
        final isCurrent = level == game.currentLevel;
        return _build3DLevelButton(level, isUnlocked, isCurrent);
      },
    );
  }

  Widget _build3DLevelButton(int level, bool isUnlocked, bool isCurrent) {
    return GestureDetector(
      onTap: isUnlocked ? () {
        game.currentLevel = level;
        game.resetLevel();
        game.overlays.remove('LevelMap');
        game.overlays.remove('MainMenu');
      } : null,
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: isCurrent 
                  ? [const Color(0xFFFFD700), const Color(0xFFB8860B), const Color(0xFF3E2723)]
                  : (isUnlocked 
                      ? [const Color(0xFF4A4A4A), const Color(0xFF2A2A2A), const Color(0xFF0F0F0F)]
                      : [const Color(0xFF1A1A1A), const Color(0xFF0F0F0F), Colors.black]),
              ),
              border: Border.all(
                color: isCurrent ? const Color(0xFFFFD700) : (isUnlocked ? const Color(0xFF8B5E3C) : Colors.white10),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8, offset: const Offset(4, 4)),
                if (isCurrent) BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Center(
              child: isUnlocked 
                ? Text(
                    '$level',
                    style: TextStyle(
                      color: isCurrent ? Colors.black : const Color(0xFFD4AF37),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: isCurrent ? [] : [const Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))],
                    ),
                  )
                : const Icon(Icons.lock_outline_rounded, color: Colors.white10, size: 24),
            ),
          ),
          if (isCurrent)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Icon(Icons.arrow_drop_up_rounded, color: Color(0xFFFFD700), size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumFooter(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1B242C),
        border: Border(top: BorderSide(color: Color(0xFF8B5E3C), width: 4)),
      ),
      child: Center(
        child: GestureDetector(
          onTap: () => game.overlays.remove('LevelMap'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFD4AF37), width: 2),
              boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 5, offset: Offset(2, 2))],
            ),
            child: const Text(
              'EXIT ARCHIVE',
              style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ),
        ),
      ),
    );
  }
}

