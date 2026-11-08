# 把 Launcher\ 运行时打进单文件 AML.exe
param(
    [string]$Version = '0.18.0',
    [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $root 'dist' }
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$stub = Join-Path $PSScriptRoot 'LauncherStub.cs'

$stage = Join-Path $env:TEMP ('aml-pkg-' + [guid]::NewGuid().ToString('N'))
$launcherStage = Join-Path $stage 'Launcher'
New-Item -ItemType Directory -Force -Path (Join-Path $launcherStage 'lib') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $launcherStage 'ui') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $launcherStage 'cache') | Out-Null
Copy-Item (Join-Path $root 'Launcher\Start.ps1') $launcherStage -Force
Copy-Item (Join-Path $root 'Launcher\lib\*.ps1') (Join-Path $launcherStage 'lib') -Force
Copy-Item (Join-Path $root 'Launcher\ui\*.ps1') (Join-Path $launcherStage 'ui') -Force
Copy-Item (Join-Path $root 'Launcher\cache\PglNative.dll') (Join-Path $launcherStage 'cache') -Force
if (Test-Path (Join-Path $root 'Launcher\scan-lists.ini')) { Copy-Item (Join-Path $root 'Launcher\scan-lists.ini') $launcherStage -Force }
Copy-Item (Join-Path $root 'Launcher\config.ini') (Join-Path $launcherStage 'config.ini.default') -Force

$zip = Join-Path $env:TEMP ('aml-runtime-' + [guid]::NewGuid().ToString('N') + '.zip')
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)

# 生成 A 字图标
Add-Type -AssemblyName System.Drawing
$bmp = New-Object Drawing.Bitmap 256,256
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([Drawing.Color]::FromArgb(15,15,35))
$rect = New-Object Drawing.Rectangle 12,12,232,232
$path = New-Object Drawing.Drawing2D.GraphicsPath
$r = 52
$path.AddArc($rect.X,$rect.Y,$r,$r,180,90)
$path.AddArc($rect.Right-$r,$rect.Y,$r,$r,270,90)
$path.AddArc($rect.Right-$r,$rect.Bottom-$r,$r,$r,0,90)
$path.AddArc($rect.X,$rect.Bottom-$r,$r,$r,90,90)
$path.CloseFigure()
$brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(30,27,53))
$g.FillPath($brush,$path)
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(124,58,237)),8
$g.DrawPath($pen,$path)
$font = New-Object Drawing.Font -ArgumentList @('Segoe UI',[float]132,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$sf = New-Object Drawing.StringFormat
$sf.Alignment = [Drawing.StringAlignment]::Center
$sf.LineAlignment = [Drawing.StringAlignment]::Center
$white = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(226,232,240))
$g.DrawString('A',$font,$white,(New-Object Drawing.RectangleF 0,0,256,256),$sf)
$g.Dispose()
$pngStream = New-Object IO.MemoryStream
$bmp.Save($pngStream,[Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$png = $pngStream.ToArray(); $pngStream.Dispose()
$ico = Join-Path $stage 'aml.ico'
$fs = [IO.File]::Create($ico)
$bw = New-Object IO.BinaryWriter($fs)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]1)
$bw.Write([Byte]0); $bw.Write([Byte]0); $bw.Write([Byte]0); $bw.Write([Byte]0)
$bw.Write([UInt16]1); $bw.Write([UInt16]32)
$bw.Write([UInt32]$png.Length); $bw.Write([UInt32]22)
$bw.Write($png); $bw.Flush(); $bw.Close()

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$src = [IO.File]::ReadAllText($stub).Replace('__VERSION__',$Version)
$stubTmp = Join-Path $stage 'stub.cs'
[IO.File]::WriteAllText($stubTmp,$src,(New-Object Text.UTF8Encoding $true))
$exe = Join-Path $OutDir 'AML.exe'
& $csc /nologo /target:winexe /optimize+ /platform:anycpu /out:"$exe" /win32icon:"$ico" /resource:"$zip",AML.runtime.zip /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "$stubTmp"
if ($LASTEXITCODE -ne 0) { throw ('csc 失败: ' + $LASTEXITCODE) }
Write-Host ('OK: ' + $exe + '  ' + [math]::Round((Get-Item $exe).Length/1KB,1) + ' KB  v' + $Version)
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue