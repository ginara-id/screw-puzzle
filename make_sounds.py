import wave, struct, math, os

def make_wav(filename, freq, duration, sound_type='pick'):
    sample_rate = 44100
    num_samples = int(duration * sample_rate)
    with wave.open(filename, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        for i in range(num_samples):
            t = float(i) / sample_rate
            if sound_type == 'pick':
                # Quick metallic click (high pitch, fast decay)
                val = int(20000 * math.sin(2 * math.pi * freq * t) * math.exp(-30 * t))
            else:
                # Solid metallic clunk (lower pitch, slightly slower decay)
                val = int(25000 * math.sin(2 * math.pi * freq * t) * math.exp(-20 * t))
            w.writeframesraw(struct.pack('<h', val))

os.makedirs('assets/audio', exist_ok=True)
make_wav('assets/audio/pick.wav', 1800, 0.15, 'pick')
make_wav('assets/audio/drop.wav', 800, 0.2, 'drop')
print("Sounds created successfully")
