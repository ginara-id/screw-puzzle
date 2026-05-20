import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LangService {
  static final LangService _instance = LangService._internal();
  factory LangService() => _instance;
  LangService._internal();

  final ValueNotifier<String> localeNotifier = ValueNotifier<String>('id');

  static const Map<String, String> supportedLocales = {
    'id': 'BAHASA INDONESIA',
    'en': 'ENGLISH',
    // --- FUTURE MODULES ---
    // 'jp': '日本語 (JAPANESE)',
    // 'kr': '한국어 (KOREAN)',
    // 'es': 'ESPAÑOL (SPANISH)',
    // 'cn': '简体中文 (CHINESE)',
  };

  String get currentLang => localeNotifier.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedLang = prefs.getString('system_language');
    
    if (savedLang == null) {
      // HIGH-FIDELITY AUTO-DETECTION FOR SEAMLESS ONBOARDING
      final deviceLang = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      
      // Match the OS native locale if supported, otherwise fall back safely to English.
      if (supportedLocales.containsKey(deviceLang)) {
        savedLang = deviceLang;
      } else {
        savedLang = 'en'; 
      }
      
      // Persist the auto-detected language as initial configuration
      await prefs.setString('system_language', savedLang);
    }
    
    localeNotifier.value = savedLang;
  }

  Future<void> setLanguage(String langCode) async {
    if (langCode == localeNotifier.value) return;
    localeNotifier.value = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('system_language', langCode);
  }

  void toggleLanguage() {
    final nextLang = localeNotifier.value == 'id' ? 'en' : 'id';
    setLanguage(nextLang);
  }

  static String t(String key) {
    final lang = _instance.localeNotifier.value;
    return _translations[lang]?[key] ?? _translations['en']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _translations = {
    'id': {
      // Main Menu
      'main_current_sector': 'SEKTOR AKTIF',
      'main_play': 'MULAI TRANSMISI',
      'main_coming_soon': 'SEGERA\nHADIR',
      
      // Settings
      'sett_title': 'KONFIGURASI SISTEM',
      'sett_module_controls': 'KONTROL MODUL',
      'sett_audio_title': 'AUDIO SISTEM',
      'sett_audio_subtitle': 'Output Musik & Efek',
      'sett_bgm_title': 'MUSIK LATAR (BGM)',
      'sett_bgm_subtitle': 'Kontrol musik latar permainan',
      'sett_sfx_title': 'EFEK SUARA (SFX)',
      'sett_sfx_subtitle': 'Suara benturan, baut & booster',
      'sett_documentation': 'DOKUMENTASI',
      'sett_privacy': 'KEBIJAKAN PRIVASI',
      'sett_terms': 'SYARAT LAYANAN',
      'sett_about': 'TENTANG MESIN',
      'sett_version': 'VERSI AMAN',
      'sett_language': 'BAHASA SISTEM',
      'sett_lang_display': 'Bahasa Indonesia',

      // HUD & Alerts
      'hud_time_remaining': 'SISA WAKTU',
      'hud_combo': 'KOMBO!',
      'hud_alert_storm_no_rust': 'BADAI DITOLAK: TIDAK ADA KARAT!',
      'hud_alert_chronos_active': 'CHRONOS AKTIF',
      'hud_facility_sector': 'SEKTOR FASILITAS',
      
      // Win / Lose
      'win_title': 'MISI BERHASIL',
      'win_next': 'SEKTOR BERIKUTNYA',
      'win_menu': 'MENU UTAMA',
      'win_replay': 'ULANGI SEKTOR',
      'win_integrity': 'INTEGRITAS TERVERIFIKASI: 100%',
      'lose_title': 'MISI GAGAL',
      'lose_subtitle': 'KEHABISAN WAKTU',
      'lose_retry': 'ULANGI SEKTOR',

      // Tutorial Keys
      'tuto_continue': 'LANJUTKAN',
      'tuto_welcome_t': 'PROTOKOL INISIASI',
      'tuto_welcome_c': 'Selamat datang di Pabrik Baut. Misi Anda adalah melepaskan seluruh plat besi dengan memindahkan baut ke lubang kosong!',
      'tuto_timer_t': 'KRONOMETER AKTIF',
      'tuto_timer_c': 'Waktu berjalan mundur! Selesaikan misi sebelum timer mencapai nol untuk mencegah kegagalan sistem.',
      'tuto_sel_left_t': 'LANGKAH 1: SELEKSI',
      'tuto_sel_left_c': 'Ketuk baut di ujung kiri untuk melonggarkannya dari cengkeraman besi.',
      'tuto_mov_left_t': 'LANGKAH 2: RELOKASI',
      'tuto_mov_left_c': 'Sekarang, ketuk lubang kosong di tengah bawah untuk memindahkan baut tersebut!',
      'tuto_sel_right_t': 'LANGKAH 3: KETUK BERIKUTNYA',
      'tuto_sel_right_c': 'Hebat! Sekarang ketuk baut di ujung kanan untuk melonggarkannya.',
      'tuto_mov_right_t': 'LANGKAH 4: RELOKASI',
      'tuto_mov_right_c': 'Pindahkan baut kanan ini ke lubang kosong di tengah bawah juga!',
      'tuto_swing_t': 'HUKUM FISIKA',
      'tuto_swing_c': 'Perhatikan plat yang berayun! Anda dapat memanfaatkan gravitasi untuk menjatuhkan plat secara alami.',
      'tuto_sel_cent_t': 'LANGKAH AKHIR',
      'tuto_sel_cent_c': 'Ketuk baut poros terakhir di bagian tengah!',
      'tuto_mov_cent_t': 'LEPASKAN PLAT',
      'tuto_mov_cent_c': 'Pindahkan ke salah satu lubang kosong di atas untuk menjatuhkan plat sepenuhnya!',
      
      // Level 2 Tutorial Keys
      'tuto_rust_t': '⚠️ PENGKIKISAN MANUAL',
      'tuto_rust_c': 'Baut oranye ini diselimuti karat tebal. Anda dapat menghancurkannya secara manual dengan mengetuknya sebanyak **6 KALI**!',
      'tuto_rust_hits': 'SISA KETUKAN',
      'tuto_free_t': '🔓 SEKARANG BEBAS',
      'tuto_free_c': 'Kerja bagus! Karat telah rontok sepenuhnya. Sekarang, ketuk baut ini untuk mengangkatnya dari plat!',
      'tuto_move_t': '📍 PINDAHKAN BAUT',
      'tuto_move_c': 'Pindahkan baut yang kini bebas ini ke lubang kosong di bagian atas!',
      'tuto_intro_t': '💡 STRATEGI EFEKTIF',
      'tuto_intro_c': 'Karat akhirnya hancur! Namun, mengetuk manual sebanyak 6 kali sangat membuang **waktu berharga** Anda. Aktifkan **BOOSTER STORM** untuk membersihkan SELURUH karat seketika!',
      'tuto_intro_b': 'AKTIFKAN MODUL STORM',
      'tuto_storm_t': 'MODUL 1: STORM',
      'tuto_storm_c': 'Ketuk modul STORM (ditunjuk di bawah) untuk melepaskan badai petir masif yang membersihkan seluruh karat secara instan!',
      'tuto_smash_t': 'MODUL 2: SMASH',
      'tuto_smash_c': 'Hebat! Selanjutnya adalah SMASH. Jika plat bertumpuk rumit, ketuk modul ini untuk menghancurkan satu plat besi secara acak!',
      'tuto_smash_b': 'PELAJARI SMASH',
      'tuto_smash_try_c': 'Ketuk tombol SMASH di bawah untuk menghancurkan plat penghalang secara instan!',
      'tuto_chronos_t': 'MODUL 3: CHRONOS',
      'tuto_chronos_c': 'Terakhir! Ketuk modul CHRONOS untuk membekukan jalannya waktu secara total agar Anda bisa berpikir jernih saat kritis!',
      'tuto_chronos_b': 'PELAJARI CHRONOS',
      'tuto_chronos_try_c': 'Bagus! Ketuk CHRONOS untuk membekukan waktu selama 10 detik. Selesaikan level ini sekarang juga!',

      // Additional Unlocks & Dynamic Intro Keys
      'tuto_unlock_hint': 'SERET GEMBOK KE BAWAH UNTUK MEMBUKA!',
      'tuto_unlock_granted': 'AKSES SEKTOR DIIZINKAN!',
      'tuto_new_sector': 'INTRUSI SEKTOR BARU',
      'tuto_access_granted': 'AKSES DIIZINKAN KE SEKTOR',
      'tuto_unlock_success_desc': 'SEMUA BAUT TERKAIT TELAH DIDEKRIPSI. SISTEM PENGUNCI BERHASIL DIATUR ULANG.',
      'tuto_sector_access': 'AKSES SEKTOR',

      // Ads & Loading
      'ad_refill_booster': 'ISI ULANG {booster}',
      'ad_unlock_slot': 'BUKA SLOT',
      'ad_refill_desc': 'Tonton video singkat untuk mendapatkan +1 isi ulang booster {booster} secara instan.',
      'ad_unlock_desc': 'Tonton video singkat untuk mendapatkan akses permanen ke slot industri ini.',
      'ad_cancel': 'BATAL',
      'ad_watch': 'TONTON IKLAN',
      'ad_loading': 'MEMUAT TAYANGAN IKLAN AMAN...',

      // Splash Loader
      'splash_forging': 'MENEMPA RAKITAN...',
      'splash_heating': 'MEMANASKAN BAUT INTI...',
      'splash_testing': 'MENGUJI INTEGRITAS ALOI...',
      'splash_ready': 'SISTEM SIAP!',
    },
    'en': {
      // Main Menu
      'main_current_sector': 'CURRENT SECTOR',
      'main_play': 'START TRANSMISSION',
      'main_coming_soon': 'COMING\nSOON',
      
      // Settings
      'sett_title': 'SYSTEM CONFIG',
      'sett_module_controls': 'MODULE CONTROLS',
      'sett_audio_title': 'SYSTEM AUDIO',
      'sett_audio_subtitle': 'Music & VFX output',
      'sett_bgm_title': 'BACKGROUND MUSIC (BGM)',
      'sett_bgm_subtitle': 'Toggle background music',
      'sett_sfx_title': 'SOUND EFFECTS (SFX)',
      'sett_sfx_subtitle': 'Toggle game sound effects',
      'sett_documentation': 'DOCUMENTATION',
      'sett_privacy': 'PRIVACY POLICY',
      'sett_terms': 'TERMS OF SERVICE',
      'sett_about': 'ABOUT ENGINE',
      'sett_version': 'SECURE VERSION',
      'sett_language': 'SYSTEM LANGUAGE',
      'sett_lang_display': 'English',

      // HUD & Alerts
      'hud_time_remaining': 'TIME REMAINING',
      'hud_combo': 'COMBO!',
      'hud_alert_storm_no_rust': 'STORM DENIED: NO RUST DETECTED!',
      'hud_alert_chronos_active': 'CHRONOS ACTIVE',
      'hud_facility_sector': 'FACILITY SECTOR',
      
      // Win / Lose
      'win_title': 'VICTORY ACHIEVED',
      'win_next': 'NEXT SECTOR',
      'win_menu': 'MAIN MENU',
      'win_replay': 'REPLAY SECTOR',
      'win_integrity': 'INTEGRITY VERIFIED: 100%',
      'lose_title': 'MISSION FAILED',
      'lose_subtitle': 'TIME DEPLETED',
      'lose_retry': 'RETRY SECTOR',

      // Tutorial Keys
      'tuto_continue': 'CONTINUE',
      'tuto_welcome_t': 'INITIATION PROTOCOL',
      'tuto_welcome_c': 'Welcome to the Bolt Forge. Your mission is to release all iron plates by moving bolts to vacant holes!',
      'tuto_timer_t': 'CHRONOMETER ACTIVE',
      'tuto_timer_c': 'Time is ticking down! Complete the mission before the timer hits zero to prevent system failure.',
      'tuto_sel_left_t': 'STEP 1: SELECT',
      'tuto_sel_left_c': 'Tap the bolt on the far left to loosen it from the iron grip.',
      'tuto_mov_left_t': 'STEP 2: RELOCATE',
      'tuto_mov_left_c': 'Now, tap the vacant hole at the bottom center to move the bolt!',
      'tuto_sel_right_t': 'STEP 3: TAP NEXT',
      'tuto_sel_right_c': 'Great! Now tap the bolt on the far right to loosen it.',
      'tuto_mov_right_t': 'STEP 4: RELOCATE',
      'tuto_mov_right_c': 'Move this right bolt to the bottom center empty hole as well!',
      'tuto_swing_t': 'LAWS OF PHYSICS',
      'tuto_swing_c': 'Watch the plate swing! You can leverage gravity to make plates drop naturally.',
      'tuto_sel_cent_t': 'FINAL STEP',
      'tuto_sel_cent_c': 'Tap the final pivot bolt in the center!',
      'tuto_mov_cent_t': 'RELEASE PLATE',
      'tuto_mov_cent_c': 'Move it to any vacant hole above to drop the plate completely!',
      
      // Level 2 Tutorial Keys
      'tuto_rust_t': '⚠️ MANUAL RUST SHATTER',
      'tuto_rust_c': 'This orange bolt is covered in thick rust. You can destroy it manually by tapping it **6 TIMES**!',
      'tuto_rust_hits': 'REMAINING TAPS',
      'tuto_free_t': '🔓 NOW FREE',
      'tuto_free_c': 'Good job! The rust has crumbled away. Now, tap this bolt to lift it from the plate!',
      'tuto_move_t': '📍 RELOCATE BOLT',
      'tuto_move_c': 'Move this freed bolt to the empty hole at the top!',
      'tuto_intro_t': '💡 EFFICIENT STRATEGY',
      'tuto_intro_c': 'The rust finally shattered! However, manual tapping 6 times wastes your **precious time**. Activate **BOOSTER STORM** to cleanse ALL rust instantly!',
      'tuto_intro_b': 'ACTIVATE STORM MODULE',
      'tuto_storm_t': 'MODULE 1: STORM',
      'tuto_storm_c': 'Tap the STORM module (pointed below) to unleash a massive lightning storm that clears all rust instantly!',
      'tuto_smash_t': 'MODULE 2: SMASH',
      'tuto_smash_c': 'Awesome! Next is SMASH. If plates are stacked tightly, tap this module to completely shatter one random iron plate!',
      'tuto_smash_b': 'LEARN SMASH',
      'tuto_smash_try_c': 'Tap the SMASH button below to instantly destroy an obstructing plate!',
      'tuto_chronos_t': 'MODULE 3: CHRONOS',
      'tuto_chronos_c': 'Finally! Tap the CHRONOS module to totally freeze the flow of time so you can think clearly in tight situations!',
      'tuto_chronos_b': 'LEARN CHRONOS',
      'tuto_chronos_try_c': 'Perfect! Tap CHRONOS to freeze time for 10 seconds. Complete the level right now!',

      // Additional Unlocks & Dynamic Intro Keys
      'tuto_unlock_hint': 'DRAG LOCK DOWN TO UNLOCK!',
      'tuto_unlock_granted': 'SECTOR ACCESS GRANTED!',
      'tuto_new_sector': 'NEW SECTOR INTRUSION',
      'tuto_access_granted': 'ACCESS GRANTED TO SECTOR',
      'tuto_unlock_success_desc': 'ALL CORRESPONDING BOLTS DECRYPTED. LOCK SYSTEM FLUSHED SUCCESSFULLY.',
      'tuto_sector_access': 'SECTOR ACCESS',

      // Ads & Loading
      'ad_refill_booster': 'REFILL {booster}',
      'ad_unlock_slot': 'UNLOCK SLOT',
      'ad_refill_desc': 'Watch a short video to instantly claim +1 {booster} booster charge.',
      'ad_unlock_desc': 'Watch a short video to gain permanent access to this industrial slot.',
      'ad_cancel': 'CANCEL',
      'ad_watch': 'WATCH AD',
      'ad_loading': 'LOADING SECURE AD STREAM...',

      // Splash Loader
      'splash_forging': 'FORGING ASSEMBLIES...',
      'splash_heating': 'HEATING CORE RIVETS...',
      'splash_testing': 'TESTING ALLOY INTEGRITY...',
      'splash_ready': 'SYSTEM GO!',
    }
  };
}
