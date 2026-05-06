function Generate-Wav {
    param($Path, $Seconds, $Frequency, $Type)
    $SampleRate = 22050
    $NumSamples = [math]::Floor($SampleRate * $Seconds)
    $DataSize = $NumSamples * 2
    $FileSize = 36 + $DataSize
    
    $Stream = [System.IO.File]::Create($Path)
    $Writer = New-Object System.IO.BinaryWriter($Stream)
    
    # RIFF Header
    $Writer.Write([char[]]"RIFF")
    $Writer.Write([uint32]$FileSize)
    $Writer.Write([char[]]"WAVE")
    $Writer.Write([char[]]"fmt ")
    $Writer.Write([uint32]16)
    $Writer.Write([uint16]1) # PCM
    $Writer.Write([uint16]1) # Mono
    $Writer.Write([uint32]$SampleRate)
    $Writer.Write([uint32]($SampleRate * 2))
    $Writer.Write([uint16]2)
    $Writer.Write([uint16]16)
    $Writer.Write([char[]]"data")
    $Writer.Write([uint32]$DataSize)
    
    # Samples
    for ($i = 0; $i -lt $NumSamples; $i++) {
        $t = $i / $SampleRate
        $val = 0
        
        if ($Type -eq "menu") {
            # Deep Industrial Hum: Base (55Hz) + Harmonic (82Hz) + Tremolo
            $wave = [math]::Sin(2 * [math]::PI * $Frequency * $t) * 0.6
            $wave += [math]::Sin(2 * [math]::PI * ($Frequency * 1.5) * $t) * 0.3
            $pulse = 0.7 + 0.3 * [math]::Sin(2 * [math]::PI * 0.5 * $t) # Slow 0.5Hz pulse
            $val = [int16]($wave * $pulse * 15000)
        } elseif ($Type -eq "game") {
            # Rhythmic Factory Pulse: Low Frequency + Fast Rhythmic Pulse + Noise
            $wave = [math]::Sin(2 * [math]::PI * $Frequency * $t) * 0.8
            $pulse = 0.5 + 0.5 * [math]::Sin(2 * [math]::PI * 2.0 * $t) # 2Hz rhythmic pulse
            $noise = (Get-Random -Minimum -2000 -Maximum 2000)
            $val = [int16]($wave * $pulse * 12000 + $noise)
        } elseif ($Type -eq "noise") {
            $val = [int16]((Get-Random -Minimum -10000 -Maximum 10000))
        } else {
            # Metallic SFX: Sine + Harmonics + Decay Envelope
            $base = [math]::Sin(2 * [math]::PI * $Frequency * $t) * 0.7
            $h1 = [math]::Sin(2 * [math]::PI * ($Frequency * 1.5) * $t) * 0.2
            $h2 = [math]::Sin(2 * [math]::PI * ($Frequency * 2.2) * $t) * 0.1
            
            $fade = if ($i -gt $NumSamples * 0.5) { 
                1.0 - (($i - ($NumSamples * 0.5)) / ($NumSamples * 0.5))
            } else { 
                1.0 
            }
            
            $val = [int16](($base + $h1 + $h2) * $fade * 15000)
        }
        $Writer.Write($val)
    }
    
    $Writer.Close()
    $Stream.Dispose()
}

$AudioDir = "assets/audio"
if (-not (Test-Path $AudioDir)) { New-Item -ItemType Directory -Path $AudioDir }

Write-Host "Generating SMOOTH industrial audio files..."
Generate-Wav -Path "$AudioDir/bgm_menu.wav" -Seconds 6 -Frequency 55 -Type "menu"
Generate-Wav -Path "$AudioDir/bgm_game.wav" -Seconds 6 -Frequency 40 -Type "game"
Generate-Wav -Path "$AudioDir/bolt_tap.wav" -Seconds 0.15 -Frequency 1000 -Type "default"
Generate-Wav -Path "$AudioDir/bolt_snap.wav" -Seconds 0.25 -Frequency 500 -Type "default"
Generate-Wav -Path "$AudioDir/plate_collision.wav" -Seconds 0.35 -Frequency 120 -Type "noise"
Generate-Wav -Path "$AudioDir/victory.wav" -Seconds 3 -Frequency 660 -Type "default"
Generate-Wav -Path "$AudioDir/game_over.wav" -Seconds 3 -Frequency 150 -Type "default"
Generate-Wav -Path "$AudioDir/booster_click.wav" -Seconds 0.12 -Frequency 1400 -Type "default"
Write-Host "Audio generation complete."
