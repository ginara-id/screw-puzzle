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
        
        if ($Type -eq "scrape") {
            # Metallic scrape: base freq + harmonics + noise, enveloped
            $noise = ($Rand.NextDouble() * 2.0 - 1.0) * 8000
            $metallic = [math]::Sin(2 * [math]::PI * $Frequency * $t) * 12000
            $harmonic = [math]::Sin(2 * [math]::PI * ($Frequency * 1.5) * $t) * 8000
            
            # Fast attack, slow decay envelope
            $envelope = [math]::Exp(-8 * $t)
            
            $val = [int16](($metallic + $harmonic + $noise) * $envelope)
        }
        
        $Writer.Write([int16]$val)
    }
    
    $Writer.Close()
    $Stream.Close()
}

Generate-Wav -Path "assets/audio/scrape.wav" -Seconds 0.35 -Frequency 1100 -Type "scrape"
Write-Host "Audio file scrape.wav generated successfully!"
