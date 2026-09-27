@echo off
for %%A in ("archive") do set inputFolder=%%~fA
for %%A in ("authors.json") do set authorsFile=%%~fA
for %%A in ("stories.json") do set storiesFile=%%~fA

set PATH=%PATH%;%CoverGeneratorFolder%;

pwsh -ExecutionPolicy Bypass .\merge-story-jsons.ps1 -ArchiveFolder "%archiveFolder%" -AuthorsFile "%authorsFile%" -StoriesFile "%storiesFile%" -Apply

PAUSE