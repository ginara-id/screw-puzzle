import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flame_audio/flame_audio.dart';
import '../main.dart';
import '../utils/firebase_level_service.dart';
import '../utils/lang_service.dart';

enum SplashSequence {
  studioIntro, // 0 - 2.5s: Showing Eamon
  gameIntro,   // 2.5s - 6.5s: Showing Game Title + Loading
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  SplashSequence _currentSequence = SplashSequence.studioIntro;
  
  late AnimationController _contentController;
  late AnimationController _glowController;
  late AnimationController _loadingController;
  
  double _parallaxX = 0;
  double _parallaxY = 0;
  StreamSubscription? _gyroScopeSubscription;
  
  final List<IndustrialSpark> _sparks = List.generate(45, (index) => IndustrialSpark());

  @override
  void initState() {
    super.initState();

    // Shared Animation Drives
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 13500), // Synced precisely with machine.mp3 duration
    );

    // Physical Inertia - Store data but don't call setState here
    _gyroScopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      if (!mounted) return;
      _parallaxX = (_parallaxX + (event.y * 1.3)).clamp(-25.0, 25.0);
      _parallaxY = (_parallaxY + (event.x * 1.3)).clamp(-25.0, 25.0);
    });

    // Background Particle Sync + Parallax consolidation (60FPS)
    // This is the SINGLE point of UI update to save CPU/Battery
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        for (var s in _sparks) {
          s.update();
        }
        // Parallax values are updated by the stream, setState here 
        // will reflect the latest values along with spark positions.
      });
    });

    // --- THE MASTER CINEMATIC TIMELINE ---
    // 1. Stage 1 runs for 3 seconds.
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      // 2. Trigger crossfade transition
      setState(() {
        _currentSequence = SplashSequence.gameIntro;
      });

      // Preload all levels asynchronously in the background during the cinematic loading bar!
      FirebaseLevelService().preloadAllLevels();

      // Fire the heavy machinery startup audio!
      FlameAudio.play('machine.mp3', volume: 0.85).then((player) {
        // Run the visual loading bar at its intended cinematic speed (4 seconds)
        _loadingController.duration = const Duration(milliseconds: 4000);
        
        _loadingController.forward().then((_) {
          // Force stop the machine audio exactly when the loading bar hits 100%
          // so it doesn't spill over into the main menu!
          player.stop();
          if (mounted) _navigateToGame();
        });
      });
    });
  }

  void _navigateToGame() {
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const GameMainScreen(),
        transitionDuration: const Duration(milliseconds: 1000),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _gyroScopeSubscription?.cancel();
    _contentController.dispose();
    _glowController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Absolute black absorbs edge artifacts
      body: Stack(
        fit: StackFit.expand,
        children: [
          // BACKGROUND ATMOSPHERE
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D0D0D), Colors.black],
              ),
            ),
          ),

          // AMBIENT WELDING SPARKS
          CustomPaint(
            painter: IndustrialSparkPainter(
              sparks: _sparks,
              glowValue: _glowController.value,
            ),
          ),

          // HEAVY DEPTH VIGNETTE
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.4,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // DYNAMIC SWITCHER FOR HERO ASSETS
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1000),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                );
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: scaleAnim,
                    child: child,
                  ),
                );
              },
              child: _currentSequence == SplashSequence.studioIntro
                  ? _buildStudioHero()
                  : _buildGameHero(),
            ),
          ),
          
          // THE BOTTOM LOADING UNIT (Only active during Game Intro Stage)
          if (_currentSequence == SplashSequence.gameIntro)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOut,
                builder: (context, fade, _) => _buildModernLoader(fade),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudioHero() {
    return KeyedSubtree(
      key: const ValueKey('studio_hero'),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, _) {
          final pulse = _glowController.value;
          return _applyParallax(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft Studio Cyan Glow using GPU-optimized RadialGradient instead of expensive BoxShadow
                Container(
                  width: 220,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00E5FF).withOpacity(0.25 * pulse),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/logo_eamon.png',
                  width: 280,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (c, e, s) => const Text(
                    'EAMON STUDIO',
                    style: TextStyle(color: Colors.white54, fontSize: 24, letterSpacing: 5),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameHero() {
    return KeyedSubtree(
      key: const ValueKey('game_hero'),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, _) {
          final pulse = _glowController.value;
          return _applyParallax(
            strength: 0.6, // Heavier feel for mass
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Intense Furnace Backlight using GPU-optimized RadialGradient instead of expensive BoxShadow
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF3D00).withOpacity(0.35 * pulse),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // THE USER GORGEOUS LOGO ASSET
                Image.asset(
                  'assets/images/game_logo.png',
                  width: 360, // Bold impact sizing
                  height: 360,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _applyParallax({required Widget child, double strength = 0.4}) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateX(_parallaxY * pi / 180 * strength)
        ..rotateY(_parallaxX * pi / 180 * strength)
        ..translate(_parallaxX * 0.8, _parallaxY * 0.8, 0),
      alignment: FractionalOffset.center,
      child: child,
    );
  }

  Widget _buildModernLoader(double fade) {
    return ValueListenableBuilder<String>(
      valueListenable: LangService().localeNotifier,
      builder: (context, locale, _) {
        return AnimatedBuilder(
          animation: _loadingController,
          builder: (context, _) {
            final pct = (_loadingController.value * 100).toInt();
            
            // Dynamic system status text switching
            String status = LangService.t('splash_forging');
            if (pct > 35) status = LangService.t('splash_heating');
            if (pct > 70) status = LangService.t('splash_testing');
            if (pct > 95) status = LangService.t('splash_ready');

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: const Color(0xFFFFD180).withOpacity(fade),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    fontFamily: 'Courier',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 260,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(fade),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1 * fade), width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loadingController.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFD84315).withOpacity(fade),
                            const Color(0xFFFFB300).withOpacity(fade),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$pct%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.24 * fade),
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }
}

// Authentic Thermal Sparks System
class IndustrialSpark {
  late double x;
  late double y;
  late double size;
  late double speedY;
  late double driftX;
  late double opacity;
  late Color color;

  IndustrialSpark() { reset(); y = Random().nextDouble(); }

  void reset() {
    final r = Random();
    x = r.nextDouble();
    y = 1.1;
    size = 1.2 + r.nextDouble() * 2.5;
    speedY = 0.004 + r.nextDouble() * 0.006;
    driftX = (r.nextDouble() - 0.5) * 0.003;
    opacity = 0.4 + r.nextDouble() * 0.6;
    
    final colorRoll = r.nextDouble();
    if (colorRoll > 0.85) color = Colors.white;
    else if (colorRoll > 0.4) color = Colors.amberAccent;
    else color = const Color(0xFFFF6E40);
  }

  void update() {
    y -= speedY;
    x += driftX;
    opacity *= 0.994;
    if (y < -0.1 || opacity < 0.1) reset();
  }
}

class IndustrialSparkPainter extends CustomPainter {
  final List<IndustrialSpark> sparks;
  final double glowValue;
  IndustrialSparkPainter({required this.sparks, required this.glowValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var s in sparks) {
      paint.color = s.color.withOpacity(s.opacity);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(s.x * size.width, s.y * size.height, s.size, s.size * 3.0),
        const Radius.circular(5)
      );
      if (s.color == Colors.white) {
        canvas.drawRRect(rect, paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
      canvas.drawRRect(rect, paint..maskFilter = null);
    }
    final bottomGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [const Color(0xFFFF3D00).withOpacity(0.12 * glowValue), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bottomGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
