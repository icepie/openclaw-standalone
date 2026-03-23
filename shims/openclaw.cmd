@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "CHANGELOG_STUB=%SCRIPT_DIR%node_modules\@mariozechner\pi-coding-agent\dist\utils\changelog.js"

if not exist "%CHANGELOG_STUB%" (
  powershell -NoProfile -Command ^
    "$stub = '%CHANGELOG_STUB%'; " ^
    "if (-not (Test-Path $stub)) { " ^
    "  New-Item -ItemType Directory -Force -Path (Split-Path $stub) | Out-Null; " ^
    "  'import { fileURLToPath } from ""url""; import { dirname, join } from ""path""; const __filename = fileURLToPath(import.meta.url); const __dirname = dirname(__filename); export const getChangelogPath = () => join(__dirname, ""../../CHANGELOG.md""); export const parseChangelog = (content) => []; export const getNewEntries = async (lastVersion) => []; export const getLatestVersion = () => ""0.52.12""; export const getChangelog = async () => [];' | Set-Content -Path $stub -Encoding UTF8; " ^
    "}"
)

"%SCRIPT_DIR%node.exe" "%SCRIPT_DIR%node_modules\openclaw\openclaw.mjs" %*
