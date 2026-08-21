$files = @('public/privacy.html', 'public/terms.html')

foreach ($file in $files) {
    $content = Get-Content $file -Raw -Encoding UTF8

    # Add .page-inner CSS before .page-badge rule
    $old1 = '      .page-badge {'
    $new1 = '      .page-inner { max-width: 720px; }
      .page-badge {'
    # Only replace first occurrence
    $idx = $content.IndexOf($old1)
    if ($idx -ge 0) {
        $content = $content.Substring(0, $idx) + $new1 + $content.Substring($idx + $old1.Length)
        Write-Host "Added .page-inner CSS in $file"
    } else {
        Write-Host "WARNING: .page-badge not found in $file"
    }

    [System.IO.File]::WriteAllText((Resolve-Path $file).Path, $content, [System.Text.Encoding]::UTF8)
    Write-Host "Done: $file"
}
