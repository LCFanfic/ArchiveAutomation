@echo off
for %%A in ("archive") do set archiveFolder=%%~fA
for %%A in ("processing") do set tempFolder=%%~fA
for %%A in ("output") do set outputFolder=%%~fA

pwsh -ExecutionPolicy Bypass .\build_html_snippets_from_json.ps1 -ArchiveFolder "%archiveFolder%" -OutputFolder "%outputFolder%" -TempFolder "%tempFolder%"

PAUSE