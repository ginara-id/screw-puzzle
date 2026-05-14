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
        
        if ($Type -eq "pick") {
            # High pitched fast click
            $val = [int16](20000 * [math]::Sin(2 * [math]::PI * $Frequency * $t) * [math]::Exp(-30 * $t))
        } elseif ($Type -eq "drop") {
            # Lower pitched solid snap
            $val = [int16](25000 * [math]::Sin(2 * [math]::PI * $Frequency * $t) * [math]::Exp(-20 * $t))
        }
        
        $Writer.Write([int16]$val)
    }
    
    $Writer.Close()
    $Stream.Close()
}

if (-not (Test-Path "assets/audio")) {
    New-Item -ItemType Directory -Path "assets/audio" | Out-Null
}

Generate-Wav -Path "assets/audio/pick.wav" -Seconds 0.15 -Frequency 1500 -Type "pick"
Generate-Wav -Path "assets/audio/drop.wav" -Seconds 0.20 -Frequency 600 -Type "drop"
Write-Host "Audio files pick.wav and drop.wav generated successfully!"
