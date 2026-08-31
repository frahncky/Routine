# Normaliza screenshots para a Google Play Store:
#  - proporcao do lado maior / lado menor <= 2:1 (padding lateral com replicacao de borda)
#  - PNG 24-bit sem canal alpha
#
# Uso:  pwsh play-assets/normalize_screenshots.ps1 play-assets/phone
#       pwsh play-assets/normalize_screenshots.ps1 play-assets/phone -InPlace
param(
  [Parameter(Mandatory = $true)][string]$Dir,
  [switch]$InPlace
)

Add-Type -AssemblyName System.Drawing

$maxRatio = 2.0
$files = Get-ChildItem -Path $Dir -Filter *.png -File | Sort-Object Name
if (-not $files) { Write-Error "Nenhum PNG em $Dir"; exit 1 }

foreach ($f in $files) {
  $src = [System.Drawing.Image]::FromFile($f.FullName)
  $w = [int]$src.Width
  $h = [int]$src.Height

  # largura final: garante lado_maior / lado_menor <= 2. Se ja estiver ok, mantem.
  $targetW = $w
  if ($h -gt $w -and ($h / $w) -gt $maxRatio) {
    $targetW = [int][Math]::Ceiling($h / $maxRatio)
  }

  $bmp = New-Object System.Drawing.Bitmap($targetW, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $bmp.SetResolution(96, 96)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

  $padL = [int][Math]::Floor(($targetW - $w) / 2)
  $padR = [int]($targetW - $w - $padL)

  # 1) preenche todo o canvas replicando a coluna esquerda da origem (fundo)
  #    assim qualquer pixel nao coberto tem a cor de borda, nunca preto.
  $full = [System.Drawing.Rectangle]::new(0, 0, $targetW, $h)
  $g.DrawImage($src, $full, 0, 0, 1, $h, [System.Drawing.GraphicsUnit]::Pixel)

  # 2) imagem central
  $mid = [System.Drawing.Rectangle]::new($padL, 0, $w, $h)
  $g.DrawImage($src, $mid, 0, 0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel)

  # 3) replicacao de borda esquerda e direita
  if ($padL -gt 0) {
    $rectL = [System.Drawing.Rectangle]::new(0, 0, $padL, $h)
    $g.DrawImage($src, $rectL, 0, 0, 1, $h, [System.Drawing.GraphicsUnit]::Pixel)
  }
  if ($padR -gt 0) {
    $rx = [int]($targetW - $padR)
    $sx = [int]($w - 1)
    $rectR = [System.Drawing.Rectangle]::new($rx, 0, $padR, $h)
    $g.DrawImage($src, $rectR, $sx, 0, 1, $h, [System.Drawing.GraphicsUnit]::Pixel)
  }

  $g.Dispose(); $src.Dispose()

  $outPath = if ($InPlace) { $f.FullName } else {
    $d = Join-Path $f.DirectoryName 'normalized'
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
    Join-Path $d $f.Name
  }
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()

  $newRatio = [Math]::Round($h / $targetW, 3)
  "{0,-34} {1}x{2} -> {3}x{4}  (ratio {5})" -f $f.Name, $w, $h, $targetW, $h, $newRatio
}
