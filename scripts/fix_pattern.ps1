$file = 'public/index.html'
$content = Get-Content $file -Raw -Encoding UTF8

$startMarker = '        // DUMMY_START'
$endMarker = 'return PATTERN[patternIndex] || 0;'

$startIdx = $content.IndexOf($startMarker)
$endMarkerIdx = $content.IndexOf($endMarker, $startIdx)
# Find the closing brace + newline after the end marker
$closingBrace = $content.IndexOf('}', $endMarkerIdx)
# Include the closing brace and the newline after it
$endIdx = $closingBrace + 1

$before = $content.Substring(0, $startIdx)
$after = $content.Substring($endIdx)

$replacement = @'
        function getCellValue(col, row, cols) {
          // daysFromToday: 0 = today (bottom-right), increases going left/up
          var daysFromToday = (cols - 1 - col) * ROWS + (ROWS - 1 - row);
          if (daysFromToday >= HISTORY.length) return 0;
          return HISTORY[daysFromToday];
        }
'@

$newContent = $before + $replacement + $after
[System.IO.File]::WriteAllText((Resolve-Path $file).Path, $newContent, [System.Text.Encoding]::UTF8)
Write-Host "Done. Start=$startIdx End=$endIdx"
