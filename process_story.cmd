@echo off
for %%A in ("authors.json") do set authorsFile=%%~fA
for %%A in ("archive") do set archiveFolder=%%~fA
for %%A in ("processing") do set outputFolder=%%~fA

pwsh -ExecutionPolicy Bypass .\process_story.ps1 -AuthorsFile "%authorsFile%" -ArchiveFolder "%archiveFolder%" -OutputFolder "%outputFolder%" -InputFileOne "%~1" -InputFileTwo "%~2"

PAUSE