import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flame/effects.dart';
import 'package:flame/components.dart';
import 'package:screw_puzzle/utils/ad_service.dart';
import '../game/screw_game.dart';
import '../components/industrial_transition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lang_service.dart';
import 'firebase_level_service.dart';
import 'audio_service.dart';

class WinMenu extends StatefulWidget {
  final ScrewPuzzleGame game;
  const WinMenu({super.key, required this.game});

  @override
  State<WinMenu> createState() => _WinMenuState();
}

class _WinMenuState extends State<WinMenu> {
  late bool _showIntro;

  @override
  void initState() {
    super.initState();
    // Animasi hanya dipicu jika pengguna menyelesaikan level tertinggi yang dimilikinya
    _showIntro = widget.game.currentLevel == widget.game.highestUnlockedLevel;
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return NewLevelUnlockIntro(
        game: widget.game,
        onFinished: () {
          widget.game.overlays.remove('WinMenu');
          widget.game.nextLevel();
        },
      );
    }

    return Stack(
      children: [
        // Efficient Semi-Transparent Overlay (Zero GPU Cost)
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.7))),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFB8860B),
                    Color(0xFF3E2723),
                    Color(0xFFB8860B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildRivets(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFFFF9800),
                          size: 80,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          LangService.t('win_title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                            fontFamily: 'Courier',
                            shadows: [
                              Shadow(color: Color(0xFFFF9800), blurRadius: 15),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'INTEGRITY VERIFIED: 100%',
                          style: TextStyle(
                            color: Colors.greenAccent.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildMenuButton(
                          label: LangService.t('win_next'),
                          icon: Icons.double_arrow_rounded,
                          onPressed: () {
                            widget.game.overlays.remove('WinMenu');
                            widget.game.nextLevel();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A2A2A),
          foregroundColor: const Color(0xFFFF9800),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF444444), width: 2),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRivets() {
    return const Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -20, left: -20, child: _RivetWidget()),
          Positioned(top: -20, right: -20, child: _RivetWidget()),
          Positioned(bottom: -20, left: -20, child: _RivetWidget()),
          Positioned(bottom: -20, right: -20, child: _RivetWidget()),
        ],
      ),
    );
  }
}

class _RivetWidget extends StatelessWidget {
  const _RivetWidget();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFF444444),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.white10,
            blurRadius: 1,
            offset: Offset(-1, -1),
          ),
        ],
      ),
    );
  }
}

class NewLevelUnlockIntro extends StatefulWidget {
  final ScrewPuzzleGame game;
  final VoidCallback onFinished;

  const NewLevelUnlockIntro({
    super.key,
    required this.game,
    required this.onFinished,
  });

  @override
  State<NewLevelUnlockIntro> createState() => _NewLevelUnlockIntroState();
}

class _NewLevelUnlockIntroState extends State<NewLevelUnlockIntro>
    with TickerProviderStateMixin {
  late AnimationController _controller; // Ledakan partikel & shockwave setelah unlock
  late AnimationController _physicsController; // Loop fisika 60 FPS
  
  late List<_UnlockParticle> _particles;

  bool _isUnlocked = false;
  bool _soundPlayed = false;
  bool _isSkipped = false;

  // Pelacakan Drag
  bool _isDragging = false;
  double _dragStart = 0.0;
  double _dragOffset = 0.0;
  double _dragVelocity = 0.0;

  // Pelacakan Hovering sinusoidal
  double _idleTime = 0.0;
  double _idleY = 0.0;

  // Efek guncangan/shake jika ditarik
  double _shakeOffset = 0.0;
  double _shakeTime = 0.0;

  // Efek teks instruksi / peringatan
  String _hintText = "SERET GEMBOK KE BAWAH UNTUK MEMBUKA!";
  Color _hintColor = const Color(0xFF00E5FF);
  double _hintPulse = 1.0;

  double _lastFrameTime = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Controller ledakan partikel setelah unlock
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Physics Loop 60 FPS
    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updatePhysics)..repeat();

    // Inisialisasi partikel secara deterministik agar cepat & stabil
    final random = math.Random(42);
    _particles = List.generate(50, (index) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 150.0 + random.nextDouble() * 250.0;
      final size = 2.5 + random.nextDouble() * 4.5;
      final isSpark = random.nextDouble() > 0.35;
      return _UnlockParticle(
        angle: angle,
        speed: speed,
        size: size,
        isSpark: isSpark,
        color: isSpark
            ? (random.nextDouble() > 0.5 ? const Color(0xFFFFD700) : const Color(0xFFFF9800))
            : const Color(0xFF00E5FF), // cyan/white spark
      );
    });

    _controller.addListener(() {
      final progress = _controller.value;
      if (progress >= 0.05 && !_soundPlayed) {
        _soundPlayed = true;
        widget.game.audio.playGateOpen();
        widget.game.audio.playLightningStrike();
      }
    });

  }

  @override
  void dispose() {
    _controller.dispose();
    _physicsController.dispose();
    super.dispose();
  }

  void _updatePhysics() {
    final double currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (_lastFrameTime == 0.0) {
      _lastFrameTime = currentTime;
      return;
    }
    final double dt = (currentTime - _lastFrameTime).clamp(0.0, 0.03);
    _lastFrameTime = currentTime;

    bool changed = false;

    // 1. Guncangan gembok (shake)
    if (_shakeTime > 0.0) {
      _shakeTime -= dt * 5.0;
      _shakeOffset = math.sin(_shakeTime * 10 * math.pi) * 6.0;
      if (_shakeTime <= 0.0) {
        _shakeOffset = 0.0;
      }
      changed = true;
    }

    // 2. Hovering sinusoidal gembok
    if (!_isDragging && !_isUnlocked) {
      _idleTime += dt * 3.0;
      _idleY = math.sin(_idleTime) * 4.5;
      changed = true;
    }

    // 3. Fisika Pemulihan Pegas Gembok (jika dilepas sebelum 60px)
    if (!_isDragging && _dragOffset > 0.0 && !_isUnlocked) {
      _dragVelocity -= 450.0 * _dragOffset * dt; // F = -kx (gaya pemulih pegas kuat)
      _dragVelocity *= math.exp(-8.0 * dt); // redaman cepat
      _dragOffset += _dragVelocity * dt;
      if (_dragOffset.abs() < 0.2) {
        _dragOffset = 0.0;
        _dragVelocity = 0.0;
      }
      changed = true;
    }

    // 4. Pulsasi teks petunjuk
    _hintPulse = 1.0 + math.sin(currentTime * 4.0) * 0.15;
    changed = true;

    if (changed && mounted) {
      setState(() {});
    }
  }

  void _onDragStart(DragStartDetails details) {
    if (_isUnlocked) return;
    _isDragging = true;
    _dragStart = details.localPosition.dy;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isUnlocked) return;

    final dy = details.localPosition.dy - _dragStart;
    final prevOffset = _dragOffset;
    _dragOffset = dy.clamp(0.0, 110.0);

    if ((_dragOffset - prevOffset).abs() > 4.0) {
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging || _isUnlocked) return;
    _isDragging = false;

    if (_dragOffset >= 60.0) {
      _triggerUnlock();
    } else {
      _dragVelocity = -350.0; // kecepatan dorong awal ke atas
      widget.game.audio.playBoltSnap();
      HapticFeedback.mediumImpact();
    }
  }

  void _triggerUnlock() {
    setState(() {
      _isUnlocked = true;
      _dragOffset = 60.0;
      _hintText = "AKSES SEKTOR DIIZINKAN!";
      _hintColor = Colors.greenAccent;
    });

    HapticFeedback.heavyImpact();
    _controller.forward(from: 0.0);
  }

  void _skipIntro() {
    if (_isSkipped) return;
    _isSkipped = true;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final newLevel = widget.game.currentLevel + 1;
    const allBoltsReleased = true;

    return Stack(
      children: [
        // Latar belakang premium fiksi ilmiah gelap gulita
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFF140F08),
                  Color(0xFF060606),
                ],
                center: Alignment.center,
                radius: 1.3,
              ),
            ),
          ),
        ),

        // Grid, Partikel, Aura, & Cincin Holografik
        Positioned.fill(
          child: CustomPaint(
            painter: _UnlockIntroPainter(
              progress: _controller.value,
              particles: _particles,
              isUnlocked: _isUnlocked,
              allBoltsReleased: allBoltsReleased,
              dragOffset: _dragOffset,
              idleY: _idleY,
              shakeOffset: _shakeOffset,
            ),
          ),
        ),

        // Elemen Teks dan Tombol
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Judul Transisi Mewah
              Opacity(
                opacity: _isUnlocked ? ((_controller.value - 0.1) / 0.3).clamp(0.0, 1.0) : 0.8,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: _hintColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _hintColor.withOpacity(0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                            color: _hintColor,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          AnimatedScale(
                            scale: _hintPulse,
                            duration: const Duration(milliseconds: 150),
                            child: Text(
                              _hintText,
                              style: TextStyle(
                                color: _hintColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'NEW SECTOR INTRUSION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6.0,
                        fontFamily: 'Courier',
                        shadows: [
                          Shadow(color: Colors.white12, blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // Area Interaktif Puzzle Gembok 250x250 (Hanya Drag Vertikal)
              GestureDetector(
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 250,
                  height: 250,
                ),
              ),

              const SizedBox(height: 35),

              // Akses Level Status di Bawah
              Opacity(
                opacity: _isUnlocked ? (_controller.value / 0.4).clamp(0.0, 1.0) : 0.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: Column(
                    children: [
                      Text(
                        'ACCESS GRANTED TO SECTOR #$newLevel.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFB300),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                          fontFamily: 'Courier',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ALL CORRESPONDING BOLTS DECRYPTED. LOCK SYSTEM FLUSHED SUCCESSFULLY.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                          height: 1.4,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // Tombol Enter Sector yang menyala dan opsi menu tambahan (Replay / Home / Next)
              Opacity(
                opacity: _isUnlocked ? ((_controller.value - 0.4) / 0.3).clamp(0.0, 1.0) : 0.0,
                child: _isUnlocked
                    ? Transform.translate(
                        offset: Offset(0.0, 15.0 * (1.0 - ((_controller.value - 0.4) / 0.3).clamp(0.0, 1.0))),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Tombol Utama: SEKTOR BERIKUTNYA
                            Container(
                              width: 260,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF9800).withOpacity(0.25),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _skipIntro,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF9800),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      LangService.t('win_next'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 2.5,
                                        fontFamily: 'Courier',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 2. Tombol Sekunder Row: REPLAY & HOME
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSecondaryButton(
                                  label: LangService.t('win_replay'),
                                  icon: Icons.refresh_rounded,
                                  borderColor: const Color(0xFFFF9800).withOpacity(0.4),
                                  onPressed: () {
                                    widget.game.overlays.remove('WinMenu');
                                    widget.game.resetLevel(mode: TransitionMode.openOnly);
                                  },
                                ),
                                const SizedBox(width: 12),
                                _buildSecondaryButton(
                                  label: LangService.t('win_menu'),
                                  icon: Icons.home_rounded,
                                  borderColor: Colors.white.withOpacity(0.2),
                                  onPressed: () {
                                    widget.game.overlays.remove('WinMenu');
                                    widget.game.overlays.add('MainMenu');
                                    widget.game.audio.playMenuBGM();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required Color borderColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.5,
                fontFamily: 'Courier',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockParticle {
  final double angle;
  final double speed;
  final double size;
  final bool isSpark;
  final Color color;

  _UnlockParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.isSpark,
    required this.color,
  });
}

class _UnlockIntroPainter extends CustomPainter {
  final double progress;
  final List<_UnlockParticle> particles;
  final bool isUnlocked;
  final bool allBoltsReleased;
  final double dragOffset;
  final double idleY;
  final double shakeOffset;

  // Optimasi performa: satu Paint re-usable
  final Paint _paint = Paint();

  _UnlockIntroPainter({
    required this.progress,
    required this.particles,
    required this.isUnlocked,
    required this.allBoltsReleased,
    required this.dragOffset,
    required this.idleY,
    required this.shakeOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);

    // 1. Gambar grid latar belakang fiksi ilmiah tipis
    _paintSciFiGrid(canvas, size);

    // Hitung kemajuan animasi cincin
    final double rotProgress = isUnlocked ? 0.25 + progress * 0.75 : 0.05;
    final rotation1 = rotProgress * 2.0 * math.pi * 0.5;
    final rotation2 = -rotProgress * 2.0 * math.pi * 0.7;

    // 2. Gambar Cincin Holografik Luar (Dashed)
    _paintHolographicRing(
      canvas,
      center,
      radius: 110.0,
      rotation: rotation1,
      dashCount: 24,
      dashLength: 8.0,
      color: const Color(0xFFFF9800).withOpacity(0.2 * (1.0 - progress * 0.4)),
      strokeWidth: 1.5,
    );

    // 3. Gambar Cincin Holografik Dalam (Dashed tebal)
    _paintHolographicRing(
      canvas,
      center,
      radius: 95.0,
      rotation: rotation2,
      dashCount: 12,
      dashLength: 20.0,
      color: (allBoltsReleased ? const Color(0xFF00E5FF) : const Color(0xFFFFD700))
          .withOpacity(0.35 * (1.0 - progress * 0.5)),
      strokeWidth: 2.5,
    );

    // 4. Gambar Teks Level Menyala di Belakang Gembok
    _paintLevelText(canvas, center);

    // 5. Gambar Aura Denyut Neon Hijau/Cyan ketika kunci siap dibuka
    if (allBoltsReleased && !isUnlocked) {
      final pulse = 0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 180.0);
      _paint.style = PaintingStyle.stroke;
      _paint.strokeWidth = 2.0 + pulse * 4.0;
      _paint.color = const Color(0xFF00E5FF).withOpacity(0.12 * (1.0 - pulse * 0.3));
      _paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 + pulse * 6.0);
      canvas.drawCircle(center + Offset(0.0, dragOffset + idleY + shakeOffset), 55.0, _paint);
      _paint.maskFilter = null; // reset
    }

    // 6. Gambar Gelombang Kejut Radial (Shockwave) setelah meletup
    if (isUnlocked && progress > 0.0) {
      final tShock = progress / 0.35; // Shockwave berkembang cepat dalam 35% pertama
      if (tShock <= 1.0) {
        final shockRadius = 60.0 + tShock * 180.0;
        final shockOpacity = 1.0 - tShock;
        _paint.style = PaintingStyle.stroke;
        _paint.strokeWidth = 2.0 + (1.0 - tShock) * 7.0;
        _paint.shader = RadialGradient(
          colors: [
            const Color(0xFF00E5FF).withOpacity(0.0),
            const Color(0xFFFFD700).withOpacity(shockOpacity * 0.6),
            const Color(0xFFFFFFFF).withOpacity(shockOpacity * 0.95),
          ],
          stops: const [0.65, 0.85, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: shockRadius));

        canvas.drawCircle(center, shockRadius, _paint);
        _paint.shader = null;
      }
    }

    // 7. Gambar Partikel Ledakan
    if (isUnlocked && progress > 0.0) {
      final tPart = progress;
      _paint.style = PaintingStyle.fill;

      for (final p in particles) {
        final dist = p.speed * (1.0 - math.exp(-4.5 * tPart)) / 4.5;
        final px = center.dx + math.cos(p.angle) * dist;
        final py = center.dy + math.sin(p.angle) * dist;

        final opacity = (1.0 - tPart).clamp(0.0, 1.0);
        _paint.color = p.color.withOpacity(opacity);

        if (p.isSpark) {
          final size = p.size;
          final path = Path()
            ..moveTo(px, py - size)
            ..lineTo(px + size, py)
            ..lineTo(px, py + size)
            ..lineTo(px - size, py)
            ..close();
          canvas.drawPath(path, _paint);
        } else {
          canvas.drawCircle(Offset(px, py), p.size, _paint);
        }
      }
    }

    // 8. Gambar Gembok Mekanis Emas Kustom
    _paintInteractivePadlock(canvas, center);
  }

  void _paintSciFiGrid(Canvas canvas, Size size) {
    _paint.color = const Color(0xFFFF9800).withOpacity(0.035);
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 0.5;

    const spacing = 36.0;
    for (double x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0.0), Offset(x, size.height), _paint);
    }
    for (double y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0.0, y), Offset(size.width, y), _paint);
    }
  }

  void _paintHolographicRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double rotation,
    required int dashCount,
    required double dashLength,
    required Color color,
    required double strokeWidth,
  }) {
    _paint.color = color;
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = strokeWidth;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final angleStep = 2.0 * math.pi / dashCount;
    final dashAngle = dashLength / radius;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        dashAngle,
        false,
        _paint,
      );
    }
    canvas.restore();
  }

  void _paintLevelText(Canvas canvas, Offset center) {
    final textSpan = TextSpan(
      text: 'SECTOR ACCESS',
      style: TextStyle(
        color: Colors.white.withOpacity(0.12),
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 4.0,
        fontFamily: 'Courier',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2.0, 60.0),
    );
  }

  void _paintInteractivePadlock(Canvas canvas, Offset center) {
    double opacity = 1.0;
    if (isUnlocked) {
      opacity = (1.0 - progress / 0.5).clamp(0.0, 1.0);
    }
    if (opacity <= 0.0) return;

    final double gembokY = dragOffset + idleY + shakeOffset;

    double shackleOffset = 0.0;
    double shackleRotation = 0.0;
    double shackleXOffset = 0.0;

    if (isUnlocked) {
      final tOpen = (progress / 0.3).clamp(0.0, 1.0);
      shackleOffset = -22.0 - tOpen * 50.0;
      shackleRotation = -0.15 * tOpen * math.pi;
      shackleXOffset = -10.0 * tOpen;
    } else {
      shackleOffset = -gembokY * 0.35;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy + gembokY);

    double scale = 1.0;
    if (isUnlocked) {
      final tOpen = (progress / 0.3).clamp(0.0, 1.0);
      scale = 1.0 + 0.15 * math.sin(tOpen * math.pi);
    }
    canvas.scale(scale);

    // 1. Gambar Shackle
    canvas.save();
    canvas.translate(shackleXOffset, shackleOffset);
    canvas.rotate(shackleRotation);

    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 9.5;
    _paint.strokeCap = StrokeCap.round;
    _paint.color = Colors.white;

    _paint.shader = LinearGradient(
      colors: [
        const Color(0xFF78909C).withOpacity(opacity),
        const Color(0xFFECEFF1).withOpacity(opacity),
        const Color(0xFF455A64).withOpacity(opacity),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTRB(-35.0, -65.0, 35.0, -15.0));

    final shacklePath = Path()
      ..moveTo(-28.0, -8.0)
      ..lineTo(-28.0, -38.0)
      ..arcTo(
        Rect.fromCircle(center: const Offset(0.0, -38.0), radius: 28.0),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(28.0, -8.0);

    canvas.drawPath(shacklePath, _paint);
    _paint.shader = null;
    canvas.restore();

    // 2. Gambar Badan Gembok Emas
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0.0, 15.0), width: 80.0, height: 64.0),
      const Radius.circular(12.0),
    );

    _paint.style = PaintingStyle.fill;
    _paint.shader = LinearGradient(
      colors: [
        (allBoltsReleased ? const Color(0xFFB2FF59) : const Color(0xFFFFD54F)).withOpacity(opacity),
        (allBoltsReleased ? const Color(0xFF00E5FF) : const Color(0xFFFF8F00)).withOpacity(opacity),
        const Color(0xFF4E342E).withOpacity(opacity),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromCenter(center: const Offset(0.0, 15.0), width: 80.0, height: 64.0));

    _paint.shader = null;
    _paint.color = Colors.black.withOpacity(0.4 * opacity);
    _paint.style = PaintingStyle.fill;
    _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawRRect(bodyRect.shift(const Offset(0.0, 4.0)), _paint);
    _paint.maskFilter = null;

    canvas.drawRRect(bodyRect, _paint);
    _paint.shader = null;

    _paint.color = (allBoltsReleased ? const Color(0xFF00E5FF) : const Color(0xFF5D4037)).withOpacity(opacity);
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 2.0;
    canvas.drawRRect(bodyRect, _paint);

    // 3. Pelat Pelindung Tengah
    final plateRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0.0, 15.0), width: 44.0, height: 36.0),
      const Radius.circular(6.0),
    );
    _paint.style = PaintingStyle.fill;
    _paint.shader = LinearGradient(
      colors: [
        const Color(0xFF37221C).withOpacity(opacity),
        const Color(0xFF1E0E0B).withOpacity(opacity),
      ],
    ).createShader(Rect.fromCenter(center: const Offset(0.0, 15.0), width: 44.0, height: 36.0));

    canvas.drawRRect(plateRect, _paint);
    _paint.shader = null;

    _paint.color = (allBoltsReleased ? const Color(0xFF00E5FF) : const Color(0xFFFFB300)).withOpacity(0.3 * opacity);
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 1.0;
    canvas.drawRRect(plateRect, _paint);

    // 4. Gambar Baut Dekoratif Statis pada 4 Sudut Gembok
    _drawSingleRivet(canvas, const Offset(-32.0, -9.0), opacity);
    _drawSingleRivet(canvas, const Offset(32.0, -9.0), opacity);
    _drawSingleRivet(canvas, const Offset(-32.0, 39.0), opacity);
    _drawSingleRivet(canvas, const Offset(32.0, 39.0), opacity);

    // 5. Menggambar Lubang Kunci
    _paint.style = PaintingStyle.fill;
    _paint.color = Colors.black.withOpacity(opacity);
    canvas.drawCircle(const Offset(0.0, 10.0), 5.0, _paint);
    final keyholePath = Path()
      ..moveTo(-3.0, 10.0)
      ..lineTo(3.0, 10.0)
      ..lineTo(5.0, 23.0)
      ..lineTo(-5.0, 23.0)
      ..close();
    canvas.drawPath(keyholePath, _paint);

    _paint.color = (allBoltsReleased ? const Color(0xFF00E5FF) : const Color(0xFFFFD700)).withOpacity(0.35 * opacity);
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 0.6;
    canvas.drawCircle(const Offset(0.0, 10.0), 5.0, _paint);

    canvas.restore();
  }

  void _drawSingleRivet(Canvas canvas, Offset offset, double opacity) {
    _paint.shader = null;
    _paint.color = const Color(0xFF212121).withOpacity(opacity);
    _paint.style = PaintingStyle.fill;
    canvas.drawCircle(offset, 4.5, _paint);

    _paint.color = const Color(0xFFB0BEC5).withOpacity(opacity);
    _paint.style = PaintingStyle.fill;
    canvas.drawCircle(offset, 3.8, _paint);

    _paint.color = const Color(0xFF37474F).withOpacity(opacity);
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 1.0;
    canvas.drawLine(offset - const Offset(2.0, 0.0), offset + const Offset(2.0, 0.0), _paint);
    canvas.drawLine(offset - const Offset(0.0, 2.0), offset + const Offset(0.0, 2.0), _paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class GameOverMenu extends StatelessWidget {
  final ScrewPuzzleGame game;
  const GameOverMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.75)),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.bounceOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Colors.redAccent,
                    Color(0xFF310000),
                    Colors.redAccent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildRivets(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.report_problem_rounded,
                          color: Colors.redAccent,
                          size: 80,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          LangService.t('lose_title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            fontFamily: 'Courier',
                            shadows: [
                              Shadow(color: Colors.redAccent, blurRadius: 15),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          LangService.t('lose_subtitle'),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildMenuButton(
                          label: LangService.t('lose_retry'),
                          icon: Icons.refresh_rounded,
                          onPressed: () {
                            game.overlays.remove('GameOverMenu');
                            game.resetLevel(mode: TransitionMode.openOnly);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A2A2A),
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF440000), width: 2),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRivets() {
    return const Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -20, left: -20, child: _RivetWidget()),
          Positioned(top: -20, right: -20, child: _RivetWidget()),
          Positioned(bottom: -20, left: -20, child: _RivetWidget()),
          Positioned(bottom: -20, right: -20, child: _RivetWidget()),
        ],
      ),
    );
  }
}

class HUDMenu extends StatefulWidget {
  final ScrewPuzzleGame game;
  const HUDMenu({super.key, required this.game});

  @override
  State<HUDMenu> createState() => _HUDMenuState();
}

class _HUDMenuState extends State<HUDMenu> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bonusController;
  double _displayBonus = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bonusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    widget.game.timeBonusNotifier.addListener(_onTimeBonus);
  }

  void _onTimeBonus() {
    if (!mounted) return;
    final val = widget.game.timeBonusNotifier.value;
    if (val <= 0) return;

    setState(() {
      _displayBonus = val;
    });

    _bonusController.forward(from: 0);
  }

  @override
  void dispose() {
    widget.game.timeBonusNotifier.removeListener(_onTimeBonus);
    _pulseController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final time = widget.game.remainingTime;
        final isLowTime = time < 10 && time > 0;
        final minutes = (time / 60).floor().toString().padLeft(2, '0');
        final seconds = (time % 60).floor().toString().padLeft(2, '0');

        return SizedBox.expand(
          child: Stack(
            children: [
              // 1. CYBER FROST TIME FREEZE VIGNETTE (Cinematic Ice Overlay)
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: widget.game.timeFrozenNotifier,
                    builder: (context, isFrozen, _) {
                      if (!isFrozen) return const SizedBox.shrink();

                      // Pulsing intensity driven by constant animation frame
                      final pulse =
                          0.15 +
                          (math.sin(
                                DateTime.now().millisecondsSinceEpoch / 180,
                              ) *
                              0.08);

                      return Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 1.2,
                            colors: [
                              Colors.transparent,
                              const Color(
                                0xFF00E5FF,
                              ).withOpacity(pulse.clamp(0.0, 0.35)),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFF00E5FF,
                            ).withOpacity(pulse * 0.8),
                            width: 4.0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // --- THE ULTIMATE HYPNOTIC ARCADE HUD ---
              // Pure ambient addiction: Fills vision, screams intensity, but ignores all touch!
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: widget.game.comboUpdateNotifier,
                    builder: (context, percent, _) {
                      final count = widget.game.comboCount;
                      if (percent <= 0 || count <= 1)
                        return const SizedBox.shrink();

                      final comboColor = count == 1
                          ? const Color(0xFFFFD600)
                          : (count == 2
                                ? const Color(0xFFFF9100)
                                : const Color(0xFF00E5FF));

                      // Dynamic breathing intensity linked purely to continuous frame stream
                      final breath =
                          0.05 +
                          (math.sin(
                                DateTime.now().millisecondsSinceEpoch / 200,
                              ) *
                              0.03);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. ATMOSPHERIC SCREEN VIGNETTE (Pulsing edges hypnotize the periphery!)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                radius: 1.3,
                                colors: [
                                  Colors.transparent,
                                  comboColor.withOpacity(
                                    breath.clamp(0.0, 0.3),
                                  ),
                                ],
                                stops: const [0.7, 1.0],
                              ),
                            ),
                          ),

                          // 2. TOP & BOTTOM "CINEMA BAR" ENERGY TUBES (Visual Drain Framework)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: FractionallySizedBox(
                              alignment: Alignment.center,
                              widthFactor: percent.clamp(0.0, 1.0),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: comboColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: comboColor,
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: FractionallySizedBox(
                              alignment: Alignment.center,
                              widthFactor: percent.clamp(0.0, 1.0),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: comboColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: comboColor,
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 3. GIGANTIC GHOST BACKGROUND MULTIPLIER
                          // Rendered in center, very low opacity so it floats BEHIND focus!
                          Transform.scale(
                            // Reacts to the timer! Shrinks as combo fades!
                            scale: 0.8 + (percent * 0.7),
                            child: Text(
                              '${count}X',
                              style: TextStyle(
                                color: comboColor.withOpacity(0.08), // Apply opacity directly to the color!
                                fontSize: 180,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Courier',
                                letterSpacing: -10,
                                fontStyle: FontStyle.italic,
                                shadows: [
                                  Shadow(color: comboColor.withOpacity(0.08), blurRadius: 20), // Apply opacity to shadows!
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // --- TOP LEFT: LEVEL INDICATOR (Floating Glass Pill) ---
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: _buildGlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cyan LED Indicator
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD600).withOpacity(0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'FACILITY SECTOR',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 9,
                              letterSpacing: 2.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'SEC-${widget.game.currentLevel.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // --- TOP CENTER: TIME FREEZE ACTIVE COUNTDOWN (Floating Frozen Badge) ---
              Positioned(
                top: MediaQuery.of(context).padding.top + 80,
                left: 0,
                right: 0,
                child: Center(
                  child: ValueListenableBuilder<double>(
                    valueListenable: widget.game.freezeDurationNotifier,
                    builder: (context, duration, _) {
                      if (duration <= 0) return const SizedBox.shrink();

                      final secsStr = duration.toStringAsFixed(1);

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00111A).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withOpacity(0.8),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.ac_unit_rounded,
                                color: Color(0xFF00E5FF),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'CHRONOS: ${secsStr}S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Courier',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xFF00E5FF),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // --- TOP RIGHT: CONTROLS (Floating Glass Pill) ---
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: _buildGlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildIconButton(
                        icon: Icons.home_rounded,
                        onPressed: () {
                          widget.game.overlays.remove('HUD');
                          widget.game.overlays.add('MainMenu');
                          widget.game.audio.playMenuBGM();
                        },
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.white.withOpacity(0.2),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      _buildIconButton(
                        icon: Icons.refresh_rounded,
                        onPressed: () => widget.game.resetLevel(),
                      ),
                    ],
                  ),
                ),
              ),

              // --- BOTTOM: MAIN DOCK (Floating Glass Panel) ---
              Positioned(
                bottom: 25 + MediaQuery.of(context).padding.bottom,
                left: 16,
                right: 16,
                child: _buildGlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  borderRadius: BorderRadius.circular(35),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Boosters
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBoosterItem(
                            Icons.ac_unit_rounded,
                            'CHRONOS',
                            const Color(0xFF00E5FF),
                            onTap: widget.game.useTimeFreezeBooster,
                          ),
                          const SizedBox(width: 16),
                          _buildBoosterItem(
                            Icons.gavel_rounded,
                            'SMASH',
                            const Color(0xFFFF9800),
                            onTap: widget.game.usePlateSmashBooster,
                          ),
                          const SizedBox(width: 16),
                          _buildBoosterItem(
                            Icons.bolt_rounded,
                            'STORM',
                            const Color(0xFFFFD600),
                            onTap: widget.game.useRustCleanseBooster,
                          ),
                        ],
                      ),

                      // Elegant Vertical Divider
                      Container(
                        width: 1,
                        height: 45,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),

                      // High-Tech Timer Display
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // --- ULTIMATE INTEGRATION: IN-DOCK ENERGY METER ---
                            // This lives permanently INSIDE the bottom dock reserved area.
                            // It is mathematically impossible for it to block dynamic objects!
                            ValueListenableBuilder<double>(
                              valueListenable: widget.game.comboUpdateNotifier,
                              builder: (context, percent, _) {
                                final count = widget.game.comboCount;
                                final isActive = percent > 0 && count > 1;
                                final comboColor = count == 1
                                    ? const Color(0xFFFFD600)
                                    : (count == 2
                                          ? const Color(0xFFFF9100)
                                          : const Color(0xFF00E5FF));

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  height: isActive
                                      ? 14
                                      : 0, // Slides in gracefully!
                                  margin: EdgeInsets.only(
                                    bottom: isActive ? 2 : 0,
                                  ),
                                  curve: Curves.easeOut,
                                  child: OverflowBox(
                                    minHeight: 0,
                                    maxHeight: 14,
                                    alignment: Alignment.bottomRight,
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      opacity: isActive ? 1.0 : 0.0,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Micro Glowing Icon
                                          Icon(
                                            Icons.bolt_rounded,
                                            size: 10,
                                            color: comboColor,
                                          ),
                                          Text(
                                            '${count}X',
                                            style: TextStyle(
                                              color: comboColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'Courier',
                                              shadows: [
                                                Shadow(
                                                  color: comboColor,
                                                  blurRadius: 5,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Embedded Nano Tube
                                          Container(
                                            width: 55,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              border: Border.all(
                                                color: comboColor.withOpacity(
                                                  0.3,
                                                ),
                                                width: 0.5,
                                              ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Stack(
                                              children: [
                                                FractionallySizedBox(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  widthFactor: percent.clamp(
                                                    0.0,
                                                    1.0,
                                                  ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          comboColor,
                                                          Colors.white,
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: widget.game.timeFrozenNotifier,
                              builder: (context, isFrozen, _) {
                                final isLowTime = time < 10 && !isFrozen;
                                return Text(
                                  '$minutes:$seconds',
                                  style: TextStyle(
                                    color: isFrozen
                                        ? const Color(0xFF00E5FF)
                                        : (isLowTime
                                              ? (time.floor() % 2 == 0
                                                    ? const Color(0xFFFF3333)
                                                    : Colors.white)
                                              : Colors.white),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Courier',
                                    shadows: [
                                      Shadow(
                                        color: isFrozen
                                            ? const Color(
                                                0xFF00E5FF,
                                              ).withOpacity(0.6)
                                            : (isLowTime
                                                  ? const Color(0xFFFF3333)
                                                  : const Color(
                                                      0xFFFFD600,
                                                    ).withOpacity(0.6)),
                                        blurRadius: 15,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Text(
                              LangService.t('hud_time_remaining'),
                              style: TextStyle(
                                color: const Color(0xFFFFD600).withOpacity(0.6),
                                fontSize: 8,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. DYNAMIC FLOATING HUD ALERTS (Cyber Warning System)
              Positioned(
                top:
                    MediaQuery.of(context).size.height *
                    0.45, // Centered but slightly above midpoint
                left: 0,
                right: 0,
                child: ValueListenableBuilder<String?>(
                  valueListenable: widget.game.alertNotifier,
                  builder: (context, message, _) {
                    if (message == null) return const SizedBox.shrink();

                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, _) {
                        return Transform.scale(
                          scale: scale,
                          child: Center(
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFF3D00),
                                    width: 1.5,
                                  ), // Danger Red/Orange
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF3D00,
                                      ).withOpacity(0.35),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFFF3D00),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      message,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Core Glassmorphism Container Generator
  Widget _buildGlassContainer({
    required Widget child,
    required EdgeInsets padding,
    required BorderRadius borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 5,
          sigmaY: 5,
        ), // Optimized blur for better FPS
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(
              0xFF1A1A1A,
            ).withOpacity(0.65), // Rich carbon graphite tint
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.2,
            ), // Hairline highlight
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: -5,
              ),
              BoxShadow(
                color: const Color(0xFFFFD600).withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 5,
              ), // Cyan ambient glow
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
      splashColor: const Color(0xFFFFD600).withOpacity(0.3),
      highlightColor: Colors.transparent,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(10),
    );
  }

  Widget _buildBoosterItem(
    IconData icon,
    String label,
    Color accentColor, {
    VoidCallback? onTap,
  }) {
    ValueNotifier<int>? countNotifier;
    if (label == 'STORM') countNotifier = widget.game.stormCountNotifier;
    if (label == 'SMASH') countNotifier = widget.game.smashCountNotifier;
    if (label == 'CHRONOS') countNotifier = widget.game.chronosCountNotifier;

    final isLocked =
        widget.game.currentLevel == 1; // Controls level 1 padlock visualization
    final step = widget.game.tutorialStepNotifier.value;

    // Calculate whether interaction is blocked
    bool isClickBlocked = isLocked;
    if (step != null) {
      isClickBlocked =
          true; // Default block during ANY active tutorial dialogue

      // SELECTIVELY UNLOCK only the booster corresponding to the active trial step
      if (label == 'STORM' && step == TutorialStep.tryStorm)
        isClickBlocked = false;
      if (label == 'SMASH' && step == TutorialStep.trySmash)
        isClickBlocked = false;
      if (label == 'CHRONOS' && step == TutorialStep.tryChronos)
        isClickBlocked = false;
    }

    return GestureDetector(
      onTap: isClickBlocked
          ? null
          : () {
              widget.game.audio.playBoosterClick();
              if (onTap != null) onTap();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isClickBlocked
            ? 0.4
            : 1.0, // Dims out irrelevant boosters for visual focus!
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isClickBlocked
                        ? Colors.black.withOpacity(0.6)
                        : Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isClickBlocked
                          ? Colors.white10
                          : accentColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (!isClickBlocked)
                        BoxShadow(
                          color: accentColor.withOpacity(0.2),
                          blurRadius: 15,
                        ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: isClickBlocked ? Colors.grey : Colors.white,
                    size: 22,
                  ),
                ),

                // LOCKED / BLOCKED OVERLAY (Rendered whenever interaction is disabled)
                if (isClickBlocked)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD600).withOpacity(0.6),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black87, blurRadius: 5),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFFFFD600),
                        size: 9,
                      ),
                    ),
                  ),

                // PREMIUM BOOSTER CHARGE / INVENTORY BADGE (Replicates Lock Icon visual layout)
                if (!isClickBlocked && countNotifier != null)
                  Positioned(
                    bottom: 0, // Exact Level 1 lock position
                    right: 0, // Exact Level 1 lock position
                    child: ValueListenableBuilder<int>(
                      valueListenable: countNotifier,
                      builder: (context, count, _) {
                        final isZero = count <= 0;
                        return Container(
                          padding: const EdgeInsets.all(
                            4,
                          ), // Matched lock icon padding
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF111111,
                            ), // Exact matching dark background
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isZero
                                  ? const Color(0xFFFFD600)
                                  : accentColor.withOpacity(0.8), // Glow
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black87, blurRadius: 5),
                            ],
                          ),
                          child: isZero
                              ? const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Color(
                                    0xFFFFD600,
                                  ), // Pure play-arrow ad icon
                                  size: 9,
                                )
                              : SizedBox(
                                  width: 9,
                                  height: 9,
                                  child: Center(
                                    child: Text(
                                      '$count',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isClickBlocked
                    ? Colors.white24
                    : Colors.white.withOpacity(0.6),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final int rotation;
  const _CornerBracket({required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * math.pi / 2,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFFF9800), width: 2),
            top: BorderSide(color: Color(0xFFFF9800), width: 2),
          ),
        ),
      ),
    );
  }
}

class _HUDScannerPainter extends CustomPainter {
  final double progress;
  _HUDScannerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFFFF9800).withOpacity(0.1),
              const Color(0xFFFF9800).withOpacity(0.3),
              const Color(0xFFFF9800).withOpacity(0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
          ).createShader(
            Rect.fromLTWH(0, (progress * size.height) - 10, size.width, 20),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, (progress * size.height) - 10, size.width, 20),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HUDScannerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class MainMenu extends StatefulWidget {
  final ScrewPuzzleGame game;
  const MainMenu({super.key, required this.game});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late ScrollController _scrollController;
  int _totalLevels = 10; // Default local fallback

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // With reverse:true, each node is 150px. Scroll (currentLevel-1)*150
    // so the current level appears near the bottom of the screen on open.
    final targetOffset = ((widget.game.currentLevel - 1) * 150.0).clamp(
      0.0,
      double.infinity,
    );
    _scrollController = ScrollController(initialScrollOffset: targetOffset);
    _loadPersistedLevelCount();
  }

  Future<void> _loadPersistedLevelCount() async {
    // 1. Load from local cache immediately (Sync)
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCount = prefs.getInt('last_total_levels');
      if (savedCount != null && mounted) {
        setState(() {
          _totalLevels = savedCount;
        });
      }
    } catch (e) {
      print('Local cache load failed: $e');
    }

    // 2. Fetch fresh data from Firebase (Async)
    _fetchFreshLevelCount();
  }

  Future<void> _fetchFreshLevelCount() async {
    try {
      final count = await FirebaseLevelService().getTotalLevelCount();
      if (count > 0 && mounted) {
        setState(() {
          _totalLevels = count;
        });

        // 3. Save to local cache for offline fallback
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_total_levels', count);
      }
    } catch (e) {
      print('Firebase count sync failed: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF121212), // Pure Iron Charcoal
              Color(0xFF1F1F1F), // Warm Smelter Grey
              Color(0xFF161616), // Hard Iron Ground
            ],
          ),
        ),
        child: Stack(
          children: [
            _buildAnimatedBackground(),
            _buildParticleSystem(),
            SafeArea(
              child: Column(
                children: [
                  _buildPremiumTopBar(),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildJourneyList(),
                        _buildBottomGradient(),
                        _buildFloatingPlayButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumTopBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        // Removed expensive BackdropFilter for TopBar
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1128).withOpacity(
            0.85,
          ), // Increased opacity to maintain glass look without blur overhead
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: -5,
            ),
            BoxShadow(
              color: const Color(
                0xFFFFD600,
              ).withOpacity(0.05), // Cyan ambient glow
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD600).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_rounded,
                    color: Color(0xFFFFD600),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LangService.t('main_current_sector'),
                      style: TextStyle(
                        color: const Color(0xFFFFD600).withOpacity(0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'SCT-${widget.game.currentLevel.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontFamily: 'Courier',
                        shadows: [
                          Shadow(color: Color(0xFFFFD600), blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _buildGlassIconButton(
              icon: Icons.settings_outlined,
              onPressed: () => widget.game.overlays.add('SettingsMenu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: const Color(0xFFFFD600),
          size: 28,
        ), // Updated to Cyan
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return CustomPaint(
            painter: _ModernGridPainter(
              animValue: _animController.value,
              gridColor: const Color(
                0xFFFFD600,
              ).withOpacity(0.05), // Updated to Cyan
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticleSystem() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlePainter(animValue: _animController.value),
          );
        },
      ),
    );
  }

  Widget _buildJourneyList() {
    return ListView.builder(
      controller: _scrollController, // ← auto-scroll to current level
      reverse: true,
      padding: const EdgeInsets.only(top: 100, bottom: 200),
      physics: const BouncingScrollPhysics(),
      itemCount: _totalLevels + 1, // Dynamic Levels + 1 Coming Soon
      itemBuilder: (context, index) {
        final level = index + 1;
        final isComingSoon = level > _totalLevels;
        final isUnlocked = !isComingSoon && level <= widget.game.highestUnlockedLevel;
        final isCurrent = !isComingSoon && level == widget.game.currentLevel;

        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return _ModernJourneyNode(
              level: level,
              isUnlocked: isUnlocked,
              isCurrent: isCurrent,
              isComingSoon: isComingSoon,
              totalLevels: _totalLevels,
              game: widget.game,
              index: index,
              animValue: _animController.value,
            );
          },
        );
      },
    );
  }

  Widget _buildBottomGradient() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF0A0B0C).withOpacity(0.8),
              const Color(0xFF0A0B0C),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPlayButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40.0),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 1),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: _ModernPlayButton(
            level: widget.game.currentLevel,
            onPressed: () {
              widget.game.resetLevel(mode: TransitionMode.openOnly);
              widget.game.overlays.remove('MainMenu');
              widget.game.overlays.add('HUD');
            },
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double animValue;
  final List<Offset> particles;
  final math.Random random = math.Random(1234);

  _ParticlePainter({required this.animValue})
    : particles = List.generate(30, (i) {
        final r = math.Random(i);
        return Offset(r.nextDouble(), r.nextDouble());
      });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD600).withOpacity(0.15); // Updated to Cyan

    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      final yOffset = (animValue * 0.2 + p.dy) % 1.0;
      final xOffset = p.dx + math.sin(animValue * math.pi * 2 + i) * 0.01;

      final pos = Offset(xOffset * size.width, yOffset * size.height);
      final radius = 1.0 + math.sin(animValue * math.pi * 2 + i) * 1.0;

      canvas.drawCircle(pos, radius, paint);

      // Subtle glow
      canvas.drawCircle(
        pos,
        radius * 3,
        Paint()..color = paint.color.withOpacity(0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

class _ModernGridPainter extends CustomPainter {
  final double animValue;
  final Color gridColor;

  _ModernGridPainter({required this.animValue, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const spacing = 40.0;
    final offset = (animValue * spacing) % spacing;

    // Draw main grid
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = offset; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw larger blueprint squares
    final secondaryPaint = Paint()
      ..color = gridColor.withOpacity(gridColor.opacity * 2)
      ..strokeWidth = 1.5;

    for (double i = 0; i < size.width; i += spacing * 4) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), secondaryPaint);
    }
    for (
      double i = (offset * 4) % (spacing * 4);
      i < size.height;
      i += spacing * 4
    ) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), secondaryPaint);
    }

    // Add background gears
    _drawGear(
      canvas,
      const Offset(50, 100),
      80,
      animValue * 0.5,
      gridColor.withOpacity(0.08),
    );
    _drawGear(
      canvas,
      Offset(size.width - 40, size.height * 0.4),
      120,
      -animValue * 0.3,
      gridColor.withOpacity(0.06),
    );
    _drawGear(
      canvas,
      Offset(80, size.height * 0.7),
      60,
      animValue * 0.8,
      gridColor.withOpacity(0.05),
    );
  }

  void _drawGear(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Inner circle
    canvas.drawCircle(Offset.zero, radius * 0.4, paint);

    // Teeth
    const teethCount = 12;
    for (var i = 0; i < teethCount; i++) {
      final angle = (i * 2 * math.pi) / teethCount;
      canvas.save();
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromLTWH(radius - 5, -radius * 0.1, 15, radius * 0.2),
        paint,
      );
      canvas.restore();
    }

    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ModernGridPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

class _ModernJourneyNode extends StatelessWidget {
  final int level;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isComingSoon;
  final int totalLevels;
  final ScrewPuzzleGame game;
  final int index;
  final double animValue;

  const _ModernJourneyNode({
    required this.level,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isComingSoon,
    required this.totalLevels,
    required this.game,
    required this.index,
    required this.animValue,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = screenWidth / 2 + (screenWidth * 0.25 * math.sin(index * 1.1));
    final nextDx =
        screenWidth / 2 + (screenWidth * 0.25 * math.sin((index + 1) * 1.1));
    const cellHeight = 150.0;

    return SizedBox(
      height: cellHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Elegant Path
          if (index < totalLevels)
            Positioned.fill(
              child: CustomPaint(
                painter: _ModernPathPainter(
                  start: Offset(dx, cellHeight / 2),
                  end: Offset(nextDx, -cellHeight / 2),
                  isUnlocked: isUnlocked && (level < game.highestUnlockedLevel),
                  isComingSoon: isComingSoon,
                  animValue: animValue,
                ),
              ),
            ),

          // The Bolt Node
          Positioned(
            left: dx - 40,
            top: cellHeight / 2 - 40,
            child: _buildBoltNode(),
          ),
        ],
      ),
    );
  }

  Widget _buildBoltNode() {
    final floatY = isCurrent ? math.sin(animValue * math.pi * 2) * 8 : 0.0;

    return Transform.translate(
      offset: Offset(0, floatY),
      child: GestureDetector(
        onTap: isUnlocked
            ? () {
                game.currentLevel = level;
                game.resetLevel(mode: TransitionMode.openOnly);
                game.overlays.remove('MainMenu');
                game.overlays.add('HUD');
              }
            : null,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Optimized shadows for Impeller stability
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD600).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: CustomPaint(
            painter: _BoltNodePainter(
              isUnlocked: isUnlocked,
              isCurrent: isCurrent,
              isComingSoon: isComingSoon,
              animValue: animValue,
              level: level,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoltNodePainter extends CustomPainter {
  final bool isUnlocked;
  final bool isCurrent;
  final bool isComingSoon;
  final double animValue;
  final int level;

  _BoltNodePainter({
    required this.isUnlocked,
    required this.isCurrent,
    required this.isComingSoon,
    required this.animValue,
    required this.level,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // 1. Bolt Outer Ring
    final ringPaint = Paint()
      ..color = isCurrent
          ? const Color(0xFFFFD600).withOpacity(0.5) // Updated to Cyan
          : Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    // 2. Bolt Head (Aged Metal / Polished Copper)
    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: isUnlocked
            ? (isCurrent
                  ? [
                      const Color(0xFFFFD180), // Bright Warm Amber highlight
                      const Color(0xFFFFAB00), // Pure Rich Gold Ember
                      const Color(0xFFE65100), // Deep Furnace Base
                    ]
                  : [
                      const Color(0xFF8D8D8D),
                      const Color(0xFF424242),
                      const Color(0xFF1B1B1B),
                    ])
            : [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 5));

    canvas.drawCircle(center, radius - 5, headPaint);

    // 3. Hexagonal Detail
    final hexPath = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      final x = center.dx + (radius * 0.7) * math.cos(angle);
      final y = center.dy + (radius * 0.7) * math.sin(angle);
      if (i == 0)
        hexPath.moveTo(x, y);
      else
        hexPath.lineTo(x, y);
    }
    hexPath.close();

    final hexPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(hexPath, hexPaint);

    // 4. Philip Slot (Cross)
    final slotPaint = Paint()
      ..color = isCurrent
          ? Colors.white.withOpacity(0.9)
          : (isUnlocked
                ? Colors.black.withOpacity(0.8)
                : Colors.black.withOpacity(0.4))
      ..strokeWidth = radius * 0.12
      ..strokeCap = StrokeCap.round;

    final slotLen = radius * 0.4;
    final rotation = isCurrent ? animValue * math.pi * 0.2 : 0.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawLine(Offset(-slotLen, 0), Offset(slotLen, 0), slotPaint);
    canvas.drawLine(Offset(0, -slotLen), Offset(0, slotLen), slotPaint);
    canvas.restore();

    // 5. Level Badge (Terminal Style)
    if (isComingSoon) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: "COMING\nSOON",
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
            height: 1.0,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
      return;
    }

    if (isUnlocked) {
      final badgeRect = Rect.fromCenter(
        center: center + Offset(0, radius + 15),
        width: radius * 1.2,
        height: 20,
      );

      // Badge Background
      final badgePaint = Paint()
        ..color = isCurrent
            ? const Color(0xFFFFD600) // Updated to Cyan
            : Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
        badgePaint,
      );

      if (isCurrent) {
        final badgeGlow = Paint()
          ..color = const Color(0xFFFFD600)
              .withOpacity(0.3) // Updated to Cyan
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
          badgeGlow,
        );
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: level.toString().padLeft(2, '0'),
          style: TextStyle(
            color: isCurrent ? Colors.black : Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'Courier',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center +
            Offset(
              -textPainter.width / 2,
              radius + 15 - textPainter.height / 2,
            ),
      );
    } else {
      // Locked Icon
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.lock_outline_rounded.codePoint),
          style: TextStyle(
            fontSize: 20,
            fontFamily: Icons.lock_outline_rounded.fontFamily,
            package: Icons.lock_outline_rounded.fontPackage,
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        center - Offset(iconPainter.width / 2, iconPainter.height / 2),
      );
    }

    // 6. Current Scanning Ring
    if (isCurrent) {
      final scanPaint = Paint()
        ..color = const Color(0xFFFFD600)
            .withOpacity(0.6 * (1.0 - animValue)) // Updated to Cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius + 5 + (animValue * 15), scanPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoltNodePainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

class _ModernPathPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final bool isUnlocked;
  final bool isComingSoon;
  final double animValue;

  _ModernPathPainter({
    required this.start,
    required this.end,
    required this.isUnlocked,
    required this.isComingSoon,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isComingSoon) return; // Don't draw path to Coming Soon node yet

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(start.dx, start.dy - 60, end.dx, end.dy + 60, end.dx, end.dy);

    final basePaint = Paint()
      ..color = isUnlocked
          ? const Color(0xFFFFD600).withOpacity(0.15) // Updated to Cyan
          : Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, basePaint);

    if (isUnlocked) {
      final energyPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFD600).withOpacity(0.0), // Updated to Cyan
            const Color(0xFFFFD600),
            const Color(0xFFFFD600).withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromPoints(start, end))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // Pulse animation along the path
      final metrics = path.computeMetrics().first;
      final totalLen = metrics.length;
      final dashLen = 40.0;
      final currentPos = (animValue * totalLen) % totalLen;

      final extract = metrics.extractPath(
        currentPos,
        math.min(currentPos + dashLen, totalLen),
      );
      canvas.drawPath(extract, energyPaint);

      // If it wraps around
      if (currentPos + dashLen > totalLen) {
        final wrapExtract = metrics.extractPath(
          0,
          (currentPos + dashLen) - totalLen,
        );
        canvas.drawPath(wrapExtract, energyPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ModernPathPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

class _ModernPlayButton extends StatelessWidget {
  final int level;
  final VoidCallback onPressed;

  const _ModernPlayButton({required this.level, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 280,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF3D00),
              Color(0xFFFFAB00),
            ], // Harmonized Heat Gradient
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD600).withOpacity(0.3), // Warm Glow
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _ButtonPatternPainter()),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFFFF3D00), // Warm Heat Icon
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      '${LangService.t('main_play')} ${level.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
          .withOpacity(
            0.2,
          ) // Handled directly in painter for Impeller stability
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 10) {
      canvas.drawLine(Offset(i, 0), Offset(i - 20, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class AdConfirmationOverlay extends StatelessWidget {
  final ScrewPuzzleGame game;
  const AdConfirmationOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final isBoosterAd = game.pendingAdBooster != null;

    final titleText = isBoosterAd
        ? 'REFILL ${game.pendingAdBooster}'
        : 'UNLOCK SLOT';
    final descText = isBoosterAd
        ? 'Watch a short video to instantly claim +1 ${game.pendingAdBooster} booster charge.'
        : 'Watch a short video to gain permanent access to this industrial slot.';

    IconData displayIcon = Icons.lock_open_rounded;
    if (isBoosterAd) {
      if (game.pendingAdBooster == 'STORM') displayIcon = Icons.bolt_rounded;
      if (game.pendingAdBooster == 'SMASH') displayIcon = Icons.gavel_rounded;
      if (game.pendingAdBooster == 'CHRONOS')
        displayIcon = Icons.ac_unit_rounded;
    }

    return Stack(
      children: [
        // Backdrop Blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD600), // Cyan Edge
                    Color(0xFF001F24), // Dark Sci-Fi Inner
                    Color(0xFFFFD600), // Cyan Edge
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFFD600,
                    ).withOpacity(0.2), // Cyan Shadow
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFFFD600,
                        ).withOpacity(0.1), // Cyan Light
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        displayIcon,
                        color: const Color(0xFFFFD600), // Pure Cyan
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      titleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFamily: 'Courier',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      descText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildButton(
                            label: 'CANCEL',
                            isPrimary: false,
                            onPressed: () {
                              game.overlays.remove('AdConfirmation');
                              game.pendingAdHole = null;
                              game.pendingAdBooster = null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildButton(
                            label: 'WATCH AD',
                            isPrimary: true,
                            onPressed: () {
                              game.overlays.remove('AdConfirmation');
                              game.overlays.add('Loading');

                              // PREVENT EXPLOITS: Freeze the entire physics & timer engine while watching!
                              game.paused = true;

                              AdService().showRewardedAd(
                                onAdLoaded: () {
                                  game.overlays.remove('Loading');
                                },
                                onRewardEarned: () {
                                  if (isBoosterAd) {
                                    if (game.pendingAdBooster == 'STORM')
                                      game.stormCountNotifier.value++;
                                    if (game.pendingAdBooster == 'SMASH')
                                      game.smashCountNotifier.value++;
                                    if (game.pendingAdBooster == 'CHRONOS')
                                      game.chronosCountNotifier.value++;
                                    game.saveBoosterInventory();
                                    game.audio.playVictory();
                                    game.pendingAdBooster = null;
                                  } else {
                                    if (game.pendingAdHole != null) {
                                      game.pendingAdHole!.isAdLocked = false;
                                      game.audio.playVictory();
                                      game.updateHoleHighlights();
                                      game.pendingAdHole = null;
                                    }
                                  }
                                },
                                onAdFailed: () {
                                  game.overlays.remove('Loading');
                                  game.paused =
                                      false; // Unpause engine if request errors!
                                },
                                onAdDismissed: () {
                                  // CRITICAL: Re-activate the engine no matter what once ad closes!
                                  game.paused = false;
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? const Color(0xFFFF9800)
            : Colors.transparent,
        foregroundColor: isPrimary ? Colors.black : Colors.white60,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        side: isPrimary
            ? null
            : BorderSide(color: Colors.white.withOpacity(0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final ScrewPuzzleGame game;
  const LoadingOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: Color(0xFFFF9800),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'LOADING SECURE AD STREAM...',
              style: TextStyle(
                color: const Color(0xFFFF9800).withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MASTER SYSTEM CONFIGURATION OVERLAY
// ==========================================
class SettingsMenu extends StatefulWidget {
  final ScrewPuzzleGame game;
  const SettingsMenu({super.key, required this.game});

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  late bool _bgmEnabled;
  late bool _sfxEnabled;

  @override
  void initState() {
    super.initState();
    _bgmEnabled = widget.game.audio.isBgmEnabled;
    _sfxEnabled = widget.game.audio.isSfxEnabled;
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Efficient Dimensional Overlay (No Blur overhead)
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.85)),
        ),
        // 2. Kinetic Dialog Body
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 330,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF9800).withOpacity(0.6),
                    const Color(0xFF1A1A1A),
                    const Color(0xFFFF9800).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414), // Pure industrial dark
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LangService.t('sett_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Courier',
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              widget.game.overlays.remove('SettingsMenu'),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 24),

                    // SETTINGS CATEGORY 1: SOUND & LOCALIZATION
                    _buildSettingsHeader(LangService.t('sett_module_controls')),
                    const SizedBox(height: 8),
                    _buildToggleItem(
                      icon: Icons.music_note_rounded,
                      title: LangService.t('sett_bgm_title'),
                      subtitle: LangService.t('sett_bgm_subtitle'),
                      value: _bgmEnabled,
                      onChanged: (val) async {
                        setState(() => _bgmEnabled = val);
                        await widget.game.audio.setBgmEnabled(val);
                        widget.game.audio.playBoosterClick();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildToggleItem(
                      icon: Icons.volume_up_rounded,
                      title: LangService.t('sett_sfx_title'),
                      subtitle: LangService.t('sett_sfx_subtitle'),
                      value: _sfxEnabled,
                      onChanged: (val) async {
                        setState(() => _sfxEnabled = val);
                        await widget.game.audio.setSfxEnabled(val);
                        widget.game.audio.playBoosterClick();
                      },
                    ),
                    const SizedBox(height: 8),
                    // NEW: PREMIUM GLOBAL LANGUAGE SELECTOR
                    _buildNavTile(
                      icon: Icons.language_rounded,
                      title:
                          '${LangService.t('sett_language')}: ${LangService.t('sett_lang_display').toUpperCase()}',
                      onTap: () {
                        widget.game.audio.playBoosterClick();
                        _showLanguageSelector(context);
                      },
                    ),

                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 24),

                    // SETTINGS CATEGORY 2: LEGAL & INFO
                    _buildSettingsHeader(LangService.t('sett_documentation')),
                    const SizedBox(height: 8),
                    _buildNavTile(
                      icon: Icons.privacy_tip_outlined,
                      title: LangService.t('sett_privacy'),
                      onTap: () => _launchURL(
                        'https://eamonstudio.com/boltforge/privacy-policy',
                      ),
                    ),
                    _buildNavTile(
                      icon: Icons.article_outlined,
                      title: LangService.t('sett_terms'),
                      onTap: () => _launchURL(
                        'https://eamonstudio.com/boltforge/terms-of-service',
                      ),
                    ),
                    _buildNavTile(
                      icon: Icons.info_outline_rounded,
                      title: LangService.t('sett_about'),
                      onTap: () =>
                          _launchURL('https://eamonstudio.com/boltforge'),
                    ),

                    const SizedBox(height: 32),

                    // FOOTER TELEMETRY
                    Text(
                      '${LangService.t('sett_version')}: 1.0.5-BETA',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      isScrollControlled: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decorative industrial grab bar
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  LangService.t('sett_language'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Courier',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 24),
                // Future-Proof Scalable List
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    children: LangService.supportedLocales.entries.map((entry) {
                      final bool isSelected =
                          LangService().currentLang == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () async {
                            widget.game.audio.playBoosterClick();
                            await LangService().setLanguage(entry.key);
                            Navigator.pop(ctx); // Dismiss sheet safely
                            setState(
                              () {},
                            ); // Force Settings dialog to redraw text fields
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF9800).withOpacity(0.15)
                                  : Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFF9800).withOpacity(0.8)
                                    : Colors.white.withOpacity(0.1),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontFamily: 'Courier',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFFFF9800),
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          color: const Color(0xFFFF9800).withOpacity(0.8),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          fontFamily: 'Courier',
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF9800),
            activeTrackColor: const Color(0xFFFF9800).withOpacity(0.3),
            inactiveThumbColor: Colors.grey[700],
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.white38, size: 18),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PREMIUM INTERACTIVE TUTORIAL SYSTEM ---

class TutorialOverlay extends StatefulWidget {
  final ScrewPuzzleGame game;
  const TutorialOverlay({super.key, required this.game});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    widget.game.tutorialStepNotifier.addListener(_updateState);
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.game.tutorialStepNotifier.removeListener(_updateState);
    _animController.dispose();
    super.dispose();
  }

  Offset _getWorldToScreen(Vector2 worldPos) {
    try {
      final viewfinder = widget.game.camera.viewfinder;
      final viewport = widget.game.camera.viewport;

      final offset = worldPos - viewfinder.position;
      final scaledOffset = offset * viewfinder.zoom;

      return Offset(
        (viewport.size.x / 2) + scaledOffset.x,
        (viewport.size.y / 2) + scaledOffset.y,
      );
    } catch (e) {
      return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.game.tutorialStepNotifier.value;
    if (step == null) return const SizedBox.shrink();

    String title = "";
    String content = "";
    String? buttonText;
    VoidCallback? onButtonPressed;
    Alignment alignment = const Alignment(0, 0.35);

    // Pointer configurations
    Offset? pointerPosition;
    bool showPointer = false;

    switch (step) {
      case TutorialStep.welcome:
        title = LangService.t('tuto_welcome_t');
        content = LangService.t('tuto_welcome_c');
        buttonText = LangService.t('tuto_continue');
        onButtonPressed = () {
          widget.game.tutorialStepNotifier.value = TutorialStep.explainTimer;
        };
        alignment = Alignment.center;
        break;

      case TutorialStep.explainTimer:
        title = LangService.t('tuto_timer_t');
        content = LangService.t('tuto_timer_c');
        buttonText = LangService.t('tuto_continue');
        onButtonPressed = () {
          widget.game.tutorialStepNotifier.value = TutorialStep.selectLeftBolt;
        };

        // Calculate precise dynamic coordinates of the bottom right timer
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        // Center perfectly over the timer digits in the bottom dock
        final adHeight = widget.game.hasActiveBannerAd ? 50.0 : 0.0;
        final timerX = screenWidth - 85;
        final timerY = screenHeight - (65 + bottomPadding + adHeight);

        pointerPosition = Offset(timerX, timerY);
        showPointer = true;
        alignment = const Alignment(
          0,
          -0.1,
        ); // Raised up so it doesn't overlap with the pointer and timer
        break;

      case TutorialStep.selectLeftBolt:
        title = LangService.t('tuto_sel_left_t');
        content = LangService.t('tuto_sel_left_c');
        pointerPosition = _getWorldToScreen(Vector2(-2.0, 18.0));
        showPointer = true;
        break;

      case TutorialStep.moveLeftBolt:
        title = LangService.t('tuto_mov_left_t');
        content = LangService.t('tuto_mov_left_c');
        pointerPosition = _getWorldToScreen(Vector2(-1.0, 21.5));
        showPointer = true;
        break;

      case TutorialStep.selectRightBolt:
        title = LangService.t('tuto_sel_right_t');
        content = LangService.t('tuto_sel_right_c');
        pointerPosition = _getWorldToScreen(Vector2(2.0, 18.0));
        showPointer = true;
        break;

      case TutorialStep.moveRightBolt:
        title = LangService.t('tuto_mov_right_t');
        content = LangService.t('tuto_mov_right_c');
        pointerPosition = _getWorldToScreen(Vector2(1.0, 21.5));
        showPointer = true;
        break;

      case TutorialStep.explainSwing:
        title = LangService.t('tuto_swing_t');
        content = LangService.t('tuto_swing_c');
        buttonText = LangService.t('tuto_continue');
        onButtonPressed = () {
          widget.game.tutorialStepNotifier.value =
              TutorialStep.selectCenterBolt;
        };
        break;

      case TutorialStep.selectCenterBolt:
        title = LangService.t('tuto_sel_cent_t');
        content = LangService.t('tuto_sel_cent_c');
        pointerPosition = _getWorldToScreen(Vector2(0.0, 18.0));
        showPointer = true;
        break;

      case TutorialStep.moveCenterBolt:
        title = LangService.t('tuto_mov_cent_t');
        content = LangService.t('tuto_mov_cent_c');
        // Point to the left upper vacated hole
        pointerPosition = _getWorldToScreen(Vector2(-2.0, 18.0));
        showPointer = true;
        break;

      case TutorialStep.explainRust:
        title = LangService.t('tuto_rust_t');
        content = LangService.t('tuto_rust_c');
        pointerPosition = _getWorldToScreen(
          Vector2(-2.0, 20.0),
        ); // Point straight to top-left rusty bolt
        showPointer = true;
        alignment = const Alignment(
          0,
          0.5,
        ); // Position box BEAUTIFULLY near bottom!
        break;

      case TutorialStep.selectTutorialRustBolt:
        title = LangService.t('tuto_free_t');
        content = LangService.t('tuto_free_c');
        pointerPosition = _getWorldToScreen(
          Vector2(-2.0, 20.0),
        ); // Point to target cleared bolt
        showPointer = true;
        alignment = const Alignment(0, 0.5);
        break;

      case TutorialStep.moveTutorialRustBolt:
        title = LangService.t('tuto_move_t');
        content = LangService.t('tuto_move_c');
        pointerPosition = _getWorldToScreen(
          Vector2(-2.0, 18.0),
        ); // Point to target hole
        showPointer = true;
        alignment = const Alignment(0, 0.5);
        break;

      case TutorialStep.introBoosters:
        title = LangService.t('tuto_intro_t');
        content = LangService.t('tuto_intro_c');
        buttonText = LangService.t('tuto_intro_b');
        onButtonPressed = () {
          widget.game.tutorialStepNotifier.value = TutorialStep.tryStorm;
        };
        alignment = Alignment.center;
        break;

      case TutorialStep.tryStorm:
        title = LangService.t('tuto_storm_t');
        content = LangService.t('tuto_storm_c');
        {
          final screenHeight = MediaQuery.of(context).size.height;
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          final adHeight = widget.game.hasActiveBannerAd ? 50.0 : 0.0;
          pointerPosition = Offset(
            207,
            screenHeight - (70 + adHeight + bottomPadding),
          );
          showPointer = true;
          alignment = const Alignment(0, -0.15);
        }
        break;

      case TutorialStep.explainSmash:
        title = LangService.t('tuto_smash_t');
        content = LangService.t('tuto_smash_c');
        buttonText = LangService.t('tuto_smash_b');
        onButtonPressed = () {
          widget.game.tutorialStepNotifier.value = TutorialStep.trySmash;
        };
        alignment = Alignment.center;
        break;

      case TutorialStep.trySmash:
        title = LangService.t('tuto_smash_t');
        content = LangService.t('tuto_smash_try_c');
        {
          final screenHeight = MediaQuery.of(context).size.height;
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          final adHeight = widget.game.hasActiveBannerAd ? 50.0 : 0.0;
          pointerPosition = Offset(
            137,
            screenHeight - (70 + adHeight + bottomPadding),
          );
          showPointer = true;
          alignment = const Alignment(0, -0.15);
        }
        break;

      case TutorialStep.explainChronos:
        title = LangService.t('tuto_chronos_t');
        content = LangService.t('tuto_chronos_c');
        buttonText = LangService.t('tuto_chronos_b');
        onButtonPressed = () {
          widget.game.tutorialStepNotifier.value = TutorialStep.tryChronos;
        };
        alignment = Alignment.center;
        break;

      case TutorialStep.tryChronos:
        title = LangService.t('tuto_chronos_t');
        content = LangService.t('tuto_chronos_try_c');
        {
          final screenHeight = MediaQuery.of(context).size.height;
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          final adHeight = widget.game.hasActiveBannerAd ? 50.0 : 0.0;
          pointerPosition = Offset(
            67,
            screenHeight - (70 + adHeight + bottomPadding),
          );
          showPointer = true;
          alignment = const Alignment(0, -0.15);
        }
        break;
    }

    return Stack(
      children: [
        // Full screen backdrop blur (ONLY for non-interactive welcome/explanation steps)
        if (step == TutorialStep.welcome ||
            step == TutorialStep.introBoosters ||
            step == TutorialStep.explainSmash ||
            step == TutorialStep.explainChronos)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),

        // Premium Dialog Box (Wrapped to show live, real-time manual tap counters!)
        ValueListenableBuilder<int>(
          valueListenable: widget.game.rustTutorialHitsNotifier,
          builder: (context, hits, _) {
            String finalContent = content;

            // DYNAMIC HUD UPDATE: Refresh the text with exact clicks remaining!
            if (step == TutorialStep.explainRust) {
              finalContent =
                  "${LangService.t('tuto_rust_c')}\n\n🎯 **${LangService.t('tuto_rust_hits')}: $hits / 6**";
            }

            return _TutorialDialog(
              title: title,
              content: finalContent,
              alignment: alignment,
              buttonText: buttonText,
              onButtonPressed: onButtonPressed,
            );
          },
        ),

        // Pulsing pointing element on top of active bolt/hole/booster AND dialog!
        if (showPointer &&
            pointerPosition != null &&
            pointerPosition != Offset.zero)
          IgnorePointer(
            child: _InteractivePointer(
              position: pointerPosition,
              controller: _animController,
              isTimerArrow:
                  step == TutorialStep.explainTimer ||
                  step == TutorialStep.tryStorm ||
                  step == TutorialStep.trySmash ||
                  step == TutorialStep.tryChronos,
            ),
          ),
      ],
    );
  }
}

class _InteractivePointer extends StatelessWidget {
  final Offset position;
  final AnimationController controller;
  final bool isTimerArrow;

  const _InteractivePointer({
    required this.position,
    required this.controller,
    required this.isTimerArrow,
  });

  @override
  Widget build(BuildContext context) {
    // Animate pulsing rings and bouncing arrows
    return Stack(
      children: [
        // 1. Target Pulsing Ring (Centered on element)
        Positioned(
          left: position.dx - 40,
          top: position.dy - 40,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final value = controller.value;
                return Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 40 + (value * 30),
                        height: 40 + (value * 30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFFFD600,
                            ).withOpacity((1.0 - value).clamp(0.0, 1.0)),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD600).withOpacity(
                                (0.5 * (1.0 - value)).clamp(0.0, 1.0),
                              ),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600).withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // 2. Floating bouncing pointer arrow (Always stays above or at the side)
        Positioned(
          left: position.dx - 30,
          top: isTimerArrow ? position.dy - 100 : position.dy - 110,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                // Bounce calculation
                final sinValue = math.sin(controller.value * math.pi * 2);
                final bounceOffset = sinValue * 12.0;

                return Transform.translate(
                  offset: Offset(0, bounceOffset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD600),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD600).withOpacity(0.6),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isTimerArrow
                              ? Icons.arrow_downward_rounded
                              : Icons.touch_app_rounded,
                          color: const Color(0xFFFFD600),
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Little glowing triangle pointing down
                      CustomPaint(
                        size: const Size(14, 8),
                        painter: _TrianglePainter(
                          color: const Color(0xFFFFD600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TutorialDialog extends StatelessWidget {
  final String title;
  final String content;
  final Alignment alignment;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const _TutorialDialog({
    required this.title,
    required this.content,
    required this.alignment,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E1E1E).withOpacity(0.9),
                      const Color(0xFF0D0D0D).withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD600).withOpacity(0.45),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD600).withOpacity(0.08),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cybernetic Header Bar
                    Row(
                      children: [
                        // Glowing status dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD600),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD600).withOpacity(0.8),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFFFD600),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Courier',
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFD600).withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tutorial Text Content
                    Text(
                      content,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),

                    // Action button for modal steps
                    if (buttonText != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD600,
                                ).withOpacity(0.35),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: onButtonPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD600),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                  color: Colors.white30,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  buttonText!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    fontSize: 14,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_right_alt_rounded,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
