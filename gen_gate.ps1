function Generate-Wav {
    param($Path, $Seconds, $Type)
    $SampleRate = 44100
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
    
    $Rand = New-Object System.Random
    
    # Samples
    for ($i = 0; $i -lt $NumSamples; $i++) {
        $t = $i / $SampleRate
        $val = 0.0
        
        if ($Type -eq "close") {
            # THE MOVEMENT (0.0s to 0.4s): Deep Motor Hum & Friction
            $isMoving = $t -lt 0.4
            if ($isMoving) {
                # Low frequency engine groan
                $motor = [math]::Sin(2 * [math]::PI * 60 * $t) * 4000
                $motor += [math]::Sin(2 * [math]::PI * 120 * $t) * 2000
                # Grinding friction noise
                $friction = ($Rand.NextDouble() * 2.0 - 1.0) * 3000
                $val += $motor + $friction
            }
            
            # THE CLIMAX (0.4s onwards): Massive Metallic Slam & Echo
            if ($t -ge 0.4) {
                $slamT = $t - 0.4
                # Multi-harmonic metallic clang
                $clang = [math]::Sin(2 * [math]::PI * 250 * $slamT) * 12000
                $clang += [math]::Sin(2 * [math]::PI * 600 * $slamT) * 8000
                $clang += [math]::Sin(2 * [math]::PI * 1500 * $slamT) * 4000
                # Impact noise burst
                $impactNoise = ($Rand.NextDouble() * 2.0 - 1.0) * 10000
                
                # Big reverb decay
                $decay = [math]::Exp(-8 * $slamT)
                $val += ($clang + $impactNoise) * $decay
            }
            
        } elseif ($Type -eq "open") {
            # THE UNLOCK (0.0s to 0.15s): Pneumatic Hiss & Thud
            $hissT = $t
            $hissEnvelope = [math]::Exp(-15 * $hissT)
            $hissNoise = ($Rand.NextDouble() * 2.0 - 1.0) * 12000 * $hissEnvelope
            
            $thud = [math]::Sin(2 * [math]::PI * 100 * $hissT) * 8000 * $hissEnvelope
            $val += $hissNoise + $thud
            
            # THE MOVEMENT (0.1s to 0.6s): Hydraulic Rising Drone & Sliding
            if ($t -ge 0.1 -and $t -lt 0.6) {
                $moveT = $t - 0.1
                # Pitch rises slightly as hydraulics push
                $freq = 80 + ($moveT * 40)
                $hydraulic = [math]::Sin(2 * [math]::PI * $freq * $moveT) * 5000
                $slidingNoise = ($Rand.NextDouble() * 2.0 - 1.0) * 2500
                $val += $hydraulic + $slidingNoise
            }
            
            # THE CLIMAX (0.6s onwards): Final Locking Thud
            if ($t -ge 0.6) {
                $endT = $t - 0.6
                $endThud = [math]::Sin(2 * [math]::PI * 150 * $endT) * 9000
                $endThud += ($Rand.NextDouble() * 2.0 - 1.0) * 5000
                $endDecay = [math]::Exp(-12 * $endT)
                $val += $endThud * $endDecay
            }
        }
        
        # Hard clip protection
        if ($val -gt 32767) { $val = 32767 }
        if ($val -lt -32768) { $val = -32768 }
        
        $Writer.Write([int16]$val)
    }
    
    $Writer.Close()
    $Stream.Close()
}

Generate-Wav -Path "assets/audio/gate_close.wav" -Seconds 0.9 -Type "close"
Generate-Wav -Path "assets/audio/gate_open.wav" -Seconds 0.9 -Type "open"
Write-Host "Audio files gate_close.wav and gate_open.wav generated successfully with layered mechanics!"
