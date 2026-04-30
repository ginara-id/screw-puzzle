import 'package:flutter/material.dart';
import '../game/screw_game.dart';
import '../components/industrial_transition.dart';

class WinMenu extends StatelessWidget {
  final ScrewPuzzleGame game;
  const WinMenu({super.key, required this.game});

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
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A), // Heavy iron grey
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF111111), width: 8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.9), blurRadius: 30, spreadRadius: 10),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildRivets(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest, color: Color(0xFFFF9800), size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'SYSTEM CLEARED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFF9800), // Rust/Warning Orange
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      fontFamily: 'Courier',
                      shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2))],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        game.overlays.remove('WinMenu');
                        game.nextLevel();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: const Color(0xFFFF9800),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                          side: const BorderSide(color: Color(0xFF555555), width: 3),
                        ),
                        elevation: 10,
                      ),
                      child: const Text(
                        'ENGAGE NEXT',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2, fontFamily: 'Courier'),
                      ),
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

class GameOverMenu extends StatelessWidget {
  final ScrewPuzzleGame game;
  const GameOverMenu({super.key, required this.game});

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
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF111111), width: 8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.9), blurRadius: 30, spreadRadius: 10),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildRivets(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'SYSTEM JAMMED',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      fontFamily: 'Courier',
                      shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2))],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        game.overlays.remove('GameOverMenu');
                        game.resetLevel();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                          side: const BorderSide(color: Color(0xFF555555), width: 3),
                        ),
                        elevation: 10,
                      ),
                      child: const Text('REBOOT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2, fontFamily: 'Courier')),
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

class HUDMenu extends StatelessWidget {
  final ScrewPuzzleGame game;
  const HUDMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread left and right
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level Information (LEFT) - Industrial Metal Plate
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(2), // Sharper corners for industrial
                border: Border.all(color: const Color(0xFF111111), width: 5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(2, 4)),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative Rivets
                  Positioned(left: -12, top: -4, child: Icon(Icons.circle, size: 4, color: Colors.black.withOpacity(0.5))),
                  Positioned(right: -12, top: -4, child: Icon(Icons.circle, size: 4, color: Colors.black.withOpacity(0.5))),
                  Positioned(left: -12, bottom: -4, child: Icon(Icons.circle, size: 4, color: Colors.black.withOpacity(0.5))),
                  Positioned(right: -12, bottom: -4, child: Icon(Icons.circle, size: 4, color: Colors.black.withOpacity(0.5))),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SECURE-CHANNEL',
                        style: TextStyle(
                          color: const Color(0xFFFF9800).withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'L-V-L ${game.currentLevel.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Courier',
                          letterSpacing: 3,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(2, 2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Controls (RIGHT)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconButton(
                  icon: Icons.menu, // Changed to menu icon for Map
                  onPressed: () => game.overlays.add('LevelMap'),
                ),
                const SizedBox(width: 12),
                _buildIconButton(
                  icon: Icons.refresh,
                  onPressed: () => game.resetLevel(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF111111), width: 4),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10, offset: const Offset(2, 2)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tiny rivets in corners
          Positioned(left: 2, top: 2, child: Icon(Icons.circle, size: 2, color: Colors.black.withOpacity(0.4))),
          Positioned(right: 2, top: 2, child: Icon(Icons.circle, size: 2, color: Colors.black.withOpacity(0.4))),
          Positioned(left: 2, bottom: 2, child: Icon(Icons.circle, size: 2, color: Colors.black.withOpacity(0.4))),
          Positioned(right: 2, bottom: 2, child: Icon(Icons.circle, size: 2, color: Colors.black.withOpacity(0.4))),
          
          IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: const Color(0xFFFF9800), size: 24),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class MainMenu extends StatelessWidget {
  final ScrewPuzzleGame game;
  const MainMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111), 
      child: Stack(
        children: [
          // Background Decoration: Caution Stripes (Left)
          Positioned(
            left: -50,
            top: 0,
            bottom: 0,
            width: 100,
            child: Transform.rotate(
              angle: -0.2,
              child: Opacity(
                opacity: 0.1,
                child: Column(
                  children: List.generate(20, (i) => Container(
                    height: 40,
                    color: i % 2 == 0 ? const Color(0xFFFF9800) : Colors.transparent,
                  )),
                ),
              ),
            ),
          ),
          
          // Background Decoration: Caution Stripes (Right)
          Positioned(
            right: -50,
            top: 0,
            bottom: 0,
            width: 100,
            child: Transform.rotate(
              angle: 0.2,
              child: Opacity(
                opacity: 0.1,
                child: Column(
                  children: List.generate(20, (i) => Container(
                    height: 40,
                    color: i % 2 == 0 ? const Color(0xFFFF9800) : Colors.transparent,
                  )),
                ),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Title with Pulsing Glow
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOutSine,
                  builder: (context, value, child) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withOpacity(0.1 + (value * 0.15)),
                            blurRadius: 40 + (value * 20),
                            spreadRadius: 5 + (value * 10),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'HEAVY\nMETAL\nPUZZLE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8.0,
                          height: 1.1,
                          fontFamily: 'Courier',
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 12
                            ..color = Colors.black,
                        ),
                      ),
                      const Text(
                        'HEAVY\nMETAL\nPUZZLE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8.0,
                          height: 1.1,
                          fontFamily: 'Courier',
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 10, offset: Offset(4, 4)),
                            Shadow(color: Color(0xFFFF9800), blurRadius: 2, offset: Offset(0, 0)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Subtitle / Version tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
                  ),
                  child: const Text(
                    'HYDRAULIC-SYSTEM-v2.0',
                    style: TextStyle(
                      color: Color(0xFFFF9800),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                const SizedBox(height: 100),
                
                // Action Buttons
                _buildIndustrialButton(
                  text: 'START ENGINE',
                  icon: Icons.power_settings_new_rounded,
                  onPressed: () {
                    game.overlays.remove('MainMenu');
                    game.overlays.add('HUD');
                    game.camera.viewport.add(IndustrialTransitionComponent(
                      mode: TransitionMode.openOnly,
                      onHalfway: () async {},
                    ));
                  },
                  isPrimary: true,
                ),
                
                const SizedBox(height: 20),
                
                _buildIndustrialButton(
                  text: 'SYSTEM ARCHIVE',
                  icon: Icons.storage_rounded,
                  onPressed: () {
                    game.overlays.add('LevelMap');
                  },
                  isPrimary: false,
                ),
              ],
            ),
          ),
          
          // Decorative corner rivets
          _buildCornerRivets(),
        ],
      ),
    );
  }

  Widget _buildCornerRivets() {
    return Stack(
      children: [
        Positioned(left: 20, top: 20, child: _rivetGroup()),
        Positioned(right: 20, top: 20, child: _rivetGroup()),
        Positioned(left: 20, bottom: 20, child: _rivetGroup()),
        Positioned(right: 20, bottom: 20, child: _rivetGroup()),
      ],
    );
  }

  Widget _rivetGroup() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: Colors.black.withOpacity(0.5)),
        const SizedBox(width: 8),
        Icon(Icons.circle, size: 8, color: Colors.black.withOpacity(0.5)),
      ],
    );
  }

  Widget _buildIndustrialButton({
    required String text, 
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = true,
  }) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(4, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFF2A2A2A) : const Color(0xFF1A1A1A),
          foregroundColor: const Color(0xFFFF9800),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: BorderSide(
              color: isPrimary ? const Color(0xFFFF9800).withOpacity(0.5) : const Color(0xFF111111),
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w900, 
                fontSize: 18, 
                letterSpacing: 2, 
                fontFamily: 'Courier',
              ),
            ),
          ],
        ),
      ),
    );
  }
}




