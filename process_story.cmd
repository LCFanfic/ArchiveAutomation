@echo off
for %%A in ("authors.json") do set authorsFile=%%~fA
for %%A in ("archive") do set archiveFolder=%%~fA
for %%A in ("processing") do set tempFolder=%%~fA
for %%A in ("processing\CoverGenerator") do set CoverGeneratorFolder=%%~fA
for %%A in ("output") do set outputFolder=%%~fA

set PATH=%PATH%;%CoverGeneratorFolder%;

pwsh -ExecutionPolicy Bypass .\process_story.ps1 -AuthorsFile "%authorsFile%" -ArchiveFolder "%archiveFolder%" -OutputFolder "%outputFolder%" -TempFolder "%tempFolder%" -InputFileOne "%~1" -InputFileTwo "%~2"

PAUSE