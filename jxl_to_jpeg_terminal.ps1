# ── CONFIGURAÇÕES ─────────────────────────────────────────────────
$OutputFolderName  = "jpeg-srgb"   # nome da subpasta criada dentro da pasta atual
$Quality           = 95             # qualidade JPEG (1-100)
$Workers           = 8              # workers paralelos
$Overwrite         = $false         # $true = sobrescreve existentes
$RenameFrom        = "ProPhotoRGB"  # string a substituir no nome do arquivo ("" = desativado)
$RenameTo          = "sRGB"         # string de substituição
# ──────────────────────────────────────────────────────────────────

$root = $PWD.Path
$jxls = Get-ChildItem -LiteralPath $root -Filter "*.jxl" -File

if ($jxls.Count -eq 0) {
    Write-Host "Nenhum JXL encontrado em: $root"
    return
}

$outDir = Join-Path $root $OutputFolderName
[System.IO.Directory]::CreateDirectory($outDir) | Out-Null

Write-Host "JXLs encontrados: $($jxls.Count) | Saída: $outDir | Qualidade: $Quality"

$counter = 0
$total   = $jxls.Count

$jxls | ForEach-Object -Parallel {
    $jxl        = $_.FullName
    $name       = $_.Name
    $stem       = $_.BaseName
    $outDir     = $using:outDir
    $quality    = $using:Quality
    $overwrite  = $using:Overwrite
    $renameFrom = $using:RenameFrom
    $renameTo   = $using:RenameTo

    # Aplica rename no nome do arquivo se configurado
    $outStem = if ($renameFrom -and $stem.Contains($renameFrom)) {
        $stem.Replace($renameFrom, $renameTo)
    } else { $stem }

    $outFile = Join-Path $outDir "$outStem.jpg"

    if ((Test-Path -LiteralPath $outFile) -and -not $overwrite) {
        return "SKIP | $name"
    }

    # djxl → PNG temp → magick → JPEG sRGB
    $tmpPng = [System.IO.Path]::GetTempFileName() + ".png"
    $r1 = Start-Process -FilePath "djxl" -ArgumentList "`"$jxl`"", "`"$tmpPng`"" -NoNewWindow -PassThru -Wait
    if ($r1.ExitCode -ne 0) {
        Remove-Item $tmpPng -Force -ErrorAction SilentlyContinue
        return "ERRO (djxl) | $name"
    }

    $r2 = Start-Process -FilePath "magick" -ArgumentList "`"$tmpPng`"","-colorspace", "sRGB", "-set", "exif:ColorSpace", "1", "-depth", "8", "-quality", "$quality", "`"$outFile`"" -NoNewWindow -PassThru -Wait
    Remove-Item $tmpPng -Force -ErrorAction SilentlyContinue

    if ($r2.ExitCode -ne 0) { return "ERRO (magick) | $name" }
    return "OK | $name → $outStem.jpg"

} -ThrottleLimit $Workers | ForEach-Object {
    $counter++
    Write-Host "[$counter/$total] $_"
}

Write-Host "`nConcluído. JPEGs em: $outDir"
