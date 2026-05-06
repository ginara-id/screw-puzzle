import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

class AssetGenerator {
  static Future<void> generatePlaceholders() async {
    final directory = Directory('assets/audio');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Generate BGM (Longer)
    await _generateWav('assets/audio/bgm_menu.wav', seconds: 5, frequency: 220);
    await _generateWav('assets/audio/bgm_game.wav', seconds: 5, frequency: 110);

    // Generate SFX (Shorter)
    await _generateWav('assets/audio/bolt_tap.wav', seconds: 0.1, frequency: 880);
    await _generateWav('assets/audio/bolt_snap.wav', seconds: 0.2, frequency: 440);
    await _generateWav('assets/audio/plate_collision.wav', seconds: 0.3, frequency: 100, noise: true);
    await _generateWav('assets/audio/victory.wav', seconds: 1, frequency: 660);
    await _generateWav('assets/audio/game_over.wav', seconds: 1, frequency: 220);
    await _generateWav('assets/audio/booster_click.wav', seconds: 0.1, frequency: 1200);
  }

  static Future<void> _generateWav(String path, {double seconds = 1, double frequency = 440, bool noise = false}) async {
    const int sampleRate = 22050;
    final int numSamples = (sampleRate * seconds).toInt();
    final int byteRate = sampleRate * 2;
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Size of fmt chunk
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // Mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little); // Block align
    header.setUint16(34, 16, Endian.little); // Bits per sample
    
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final Int16List samples = Int16List(numSamples);
    final Random rnd = Random();
    
    for (int i = 0; i < numSamples; i++) {
      if (noise) {
        samples[i] = (rnd.nextDouble() * 20000 - 10000).toInt();
      } else {
        double t = i / sampleRate;
        double fade = 1.0;
        if (i > numSamples * 0.8) {
           fade = (numSamples - i) / (numSamples * 0.2);
        }
        samples[i] = (sin(2 * pi * frequency * t) * 15000 * fade).toInt();
      }
    }

    final File file = File(path);
    final IOSink sink = file.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(samples.buffer.asUint8List());
    await sink.close();
  }
}
