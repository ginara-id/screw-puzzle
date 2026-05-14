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
    
    # Samples
    for ($i = 0; $i -lt $NumSamples; $i++) {
        $t = $i / $SampleRate
        $val = 0.0
        
        if ($Type -eq "tick") {
            # Urgent mechanical ticking beep
            # High frequency beep + fast exponential decay
            $beep = [math]::Sin(2 * [math]::PI * 1800 * $t) * 15000
            $decay = [math]::Exp(-30 * $t)
            $val = $beep * $decay
        }
        
        # Hard clip protection
        if ($val -gt 32767) { $val = 32767 }
        if ($val -lt -32768) { $val = -32768 }
        
        $Writer.Write([int16]$val)
    }
    
    $Writer.Close()
    $Stream.Close()
}

Generate-Wav -Path "assets/audio/tick.wav" -Seconds 0.2 -Type "tick"
Write-Host "Audio file tick.wav generated successfully!"
