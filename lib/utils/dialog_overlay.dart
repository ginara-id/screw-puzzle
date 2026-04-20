import 'package:flutter/material.dart';
import '../game/screw_game.dart';
import 'story_manager.dart';

class DialogOverlay extends StatefulWidget {
  final ScrewPuzzleGame game;
  final List<StoryBeat> beats;
  final VoidCallback onFinish;

  const DialogOverlay({
    super.key,
    required this.game,
    required this.beats,
    required this.onFinish,
  });

  @override
  State<DialogOverlay> createState() => _DialogOverlayState();
}

class _DialogOverlayState extends State<DialogOverlay> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _nextBeat() {
    if (_currentIndex < widget.beats.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final beat = widget.beats[_currentIndex];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Portrait
                    if (beat.portraitPath != null)
                      Container(
                        width: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.amber, width: 2),
                          image: DecorationImage(
                            image: AssetImage(beat.portraitPath!),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 20),
                    // Dialog Box
                    Expanded(
                      child: GestureDetector(
                        onTap: _nextBeat,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D1E12), // Dark mahogany
                            border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                beat.character == Character.silas ? "SILAS" : "UNIT 76",
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 2,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              const Divider(color: Colors.amber),
                              const SizedBox(height: 10),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    beat.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.4,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                ),
                              ),
                              const Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
