# Windows: ejecuta tests, análisis y compila. Uso: .\tools\build.ps1 [windows|apk]
param([string]$Target = "windows")
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
flutter pub get
flutter test
flutter analyze --no-fatal-infos
switch ($Target) {
  "windows" { flutter build windows --release }
  "apk"     { flutter build apk --release }
  default   { throw "Uso: .\tools\build.ps1 [windows|apk]" }
}
