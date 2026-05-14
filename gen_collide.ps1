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
    
    $Rand = New-Object System.Random
    
    # Samples
    for ($i = 0; $i -lt $NumSamples; $i++) {
        $t = $i / $SampleRate
        $val = 0
        
        if ($Type -eq "collide") {
            # Sharp metallic clank
            $noise = ($Rand.NextDouble() * 2.0 - 1.0) * 8000
            $metallic1 = [math]::Sin(2 * [math]::PI * $Frequency * $t) * 15000
            $metallic2 = [math]::Sin(2 * [math]::PI * ($Frequency * 2.1) * $t) * 10000
            $metallic3 = [math]::Sin(2 * [math]::PI * ($Frequency * 0.5) * $t) * 5000
            
            # Very fast attack, moderate decay
            $envelope = [math]::Exp(-15 * $t)
            
            $val = [int16](($metallic1 + $metallic2 + $metallic3 + $noise) * $envelope)
        }
        
        $Writer.Write([int16]$val)
    }
    
    $Writer.Close()
    $Stream.Close()
}

Generate-Wav -Path "assets/audio/collide.wav" -Seconds 0.3 -Frequency 800 -Type "collide"
Write-Host "Audio file collide.wav generated successfully!"
