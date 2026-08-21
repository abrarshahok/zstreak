$file = 'public/index.html'
$content = Get-Content $file -Raw -Encoding UTF8

# Use unique strings that don't have special chars
$start = $content.IndexOf('<section class="stats">')
$endMarker = '<section class="features"'

if ($start -lt 0 -or $content.IndexOf($endMarker) -lt 0) {
    Write-Host "Markers not found. Start=$start"
    exit 1
}

# Walk back to include the comment line before <section class="stats">
# Find the last newline before $start
$commentStart = $content.LastIndexOf("`n", $start)
# Check if there's a comment on that line
$lineStart = $content.LastIndexOf("`n", $commentStart - 1) + 1
$line = $content.Substring($lineStart, $commentStart - $lineStart)
if ($line.Contains('Stats')) {
    $start = $lineStart
} else {
    $start = $commentStart + 1
}

$endIdx = $content.IndexOf($endMarker)

$before = $content.Substring(0, $start)
$after = $content.Substring($endIdx)

$newContent = $before + $after
[System.IO.File]::WriteAllText((Resolve-Path $file).Path, $newContent, [System.Text.Encoding]::UTF8)
Write-Host "Done. Removed from $start to $endIdx"
