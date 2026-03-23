@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "CHANGELOG_STUB=%SCRIPT_DIR%node_modules\@mariozechner\pi-coding-agent\dist\utils\changelog.js"
set "CHANGELOG_DIR=%SCRIPT_DIR%node_modules\@mariozechner\pi-coding-agent\dist\utils"

if not exist "%CHANGELOG_STUB%" (
  if not exist "%CHANGELOG_DIR%" mkdir "%CHANGELOG_DIR%" >nul 2>&1
  >"%CHANGELOG_STUB%" echo export function getChangelog() { return "No changelog available." }
)

"%SCRIPT_DIR%node.exe" "%SCRIPT_DIR%node_modules\openclaw\openclaw.mjs" %*
