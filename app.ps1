param([Parameter(Mandatory=$true, Position=0)][string] $InputPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Read-Number($value, [string]$name) {
    if ($value -isnot [int] -and $value -isnot [long] -and $value -isnot [double]) {
        throw "$name must be a JSON number"
    }
    $number = [double]$value
    if (-not [double]::IsFinite($number)) { throw "$name must be finite" }
    return $number
}
function Read-WholeNumber($value, [string]$name, [long]$minimum, [long]$maximum) {
    $number = Read-Number $value $name
    if ($number -ne [Math]::Truncate($number) -or $number -lt $minimum -or $number -gt $maximum) {
        throw "$name must be a whole number between $minimum and $maximum"
    }
    return [long]$number
}

function Invoke-Analysis($data) {
    $length = Read-Number $data['scale_length_mm'] 'scale_length_mm'
    if ($length -le 0 -or $length -gt 2000) { throw 'scale_length_mm must be positive and at most 2000' }
    $first = Read-WholeNumber $data['first_fret'] 'first_fret' 1 48
    $last = Read-WholeNumber $data['last_fret'] 'last_fret' $first 48
    $frets = @(foreach ($fret in $first..$last) {
        $remaining = $length * [Math]::Pow(2, -$fret / 12)
        $previous = $length * [Math]::Pow(2, (1 - $fret) / 12)
        [ordered]@{
            fret = $fret
            from_nut_mm = [Math]::Round($length - $remaining, 3)
            from_previous_mm = [Math]::Round($previous - $remaining, 3)
            speaking_length_mm = [Math]::Round($remaining, 3)
        }
    })
    return [ordered]@{ scale_length_mm = $length; frets = $frets }
}

try {
    $payload = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json -AsHashtable
    if ($payload -isnot [System.Collections.IDictionary]) { throw 'Input must be a JSON object' }
    Invoke-Analysis $payload | ConvertTo-Json -Depth 30 -Compress
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 2
}
