import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'game/screw_game.dart';
import 'utils/overlay_manager.dart';
import 'utils/ad_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Set our beautiful interactive cyber splash as initial screen!
      home: const SplashScreen(),
    );
  }
}

class GameMainScreen extends StatefulWidget {
  const GameMainScreen({super.key});

  @override
  State<GameMainScreen> createState() => _GameMainScreenState();
}

class _GameMainScreenState extends State<GameMainScreen> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    // Start loading Ads specifically when entering the Game view
    _bannerAd = AdService().createBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. FULL SCREEN GAME (Background will reach the bottom)
          Positioned.fill(
            child: GameWidget<ScrewPuzzleGame>.controlled(
              gameFactory: ScrewPuzzleGame.new,
              overlayBuilderMap: {
                'MainMenu': (context, game) => Padding(
                      padding: EdgeInsets.only(
                          bottom: _bannerAd != null ? _bannerAd!.size.height.toDouble() : 0),
                      child: MainMenu(game: game),
                    ),
                'WinMenu': (context, game) => Padding(
                      padding: EdgeInsets.only(
                          bottom: _bannerAd != null ? _bannerAd!.size.height.toDouble() : 0),
                      child: WinMenu(game: game),
                    ),
                'GameOverMenu': (context, game) => Padding(
                      padding: EdgeInsets.only(
                          bottom: _bannerAd != null ? _bannerAd!.size.height.toDouble() : 0),
                      child: GameOverMenu(game: game),
                    ),
                'HUD': (context, game) {
                  game.hasActiveBannerAd = (_bannerAd != null);
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: _bannerAd != null ? _bannerAd!.size.height.toDouble() : 0),
                    child: HUDMenu(game: game),
                  );
                },
                'AdConfirmation': (context, game) => AdConfirmationOverlay(game: game),
                'Loading': (context, game) => LoadingOverlay(game: game),
                'SettingsMenu': (context, game) => SettingsMenu(game: game),
                'Tutorial': (context, game) {
                  game.hasActiveBannerAd = (_bannerAd != null);
                  return TutorialOverlay(game: game);
                },
              },
            ),
          ),
          // 2. OVERLAY BANNER (Floating on top of background)
          if (_bannerAd != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
