@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "CHANGELOG_STUB=%SCRIPT_DIR%node_modules\@mariozechner\pi-coding-agent\dist\utils\changelog.js"

if not exist "%CHANGELOG_STUB%" (
  powershell -NoProfile -Command ^
    "$stub = '%CHANGELOG_STUB%'; " ^
    "if (-not (Test-Path $stub)) { " ^
    "  New-Item -ItemType Directory -Force -Path (Split-Path $stub) | Out-Null; " ^
    "  'export function getChangelog() { return ""No changelog available."" }' | Set-Content -Path $stub -Encoding UTF8; " ^
    "}"
)

"%SCRIPT_DIR%node.exe" "%SCRIPT_DIR%node_modules\openclaw\openclaw.mjs" %*
