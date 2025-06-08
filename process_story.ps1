param (
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_ -PathType Leaf}, ErrorMessage = "File does not exist.")]
  [string]$InputFileOne,

  [Parameter(Mandatory=$false)]
  [ValidateScript({!$_ -or {Test-Path $_ -PathType Leaf}}, ErrorMessage = "File does not exist.")]
  [string]$InputFileTwo,

  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_ -PathType Leaf}, ErrorMessage = "File does not exist.")]
  [string]$AuthorsFile,

  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_ -PathType Container}, ErrorMessage = "Folder does not exist.")]
  [string]$ArchiveFolder,

  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_ -PathType Container}, ErrorMessage = "Folder does not exist.")]
  [string]$TempFolder,

  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_ -PathType Container}, ErrorMessage = "Folder does not exist.")]
  [string]$OutputFolder
)

Set-StrictMode -Version 2

$pandocFolder = Join-Path -Path $PSScriptRoot -ChildPath "pandoc"

$processSubmissionLuaFilter = Join-Path -Path $pandocFolder -ChildPath "process-submission.lua"
$getMetadataJsonLuaFilter   = Join-Path -Path $pandocFolder -ChildPath "get-metadata-as-json.lua"
$customHRLuaFilter          = Join-Path -Path $pandocFolder -ChildPath "custom-hr.lua"
$authorsLuaFilter           = Join-Path -Path $pandocFolder -ChildPath "authors.lua"
$websiteAdjustmentLuaFilter = Join-Path -Path $pandocFolder -ChildPath "website-adjustment.lua"
$extractPrefaceLuaFilter    = Join-Path -Path $pandocFolder -ChildPath "extract-preface.lua"
$headingFinderLuaFilter     = Join-Path -Path $pandocFolder -ChildPath "heading-finder.lua"
$escapePlaintextLuaFilter   = Join-Path -Path $pandocFolder -ChildPath "escape-plaintext.lua"

$metadataJsonTemplate       = Join-Path -Path $pandocFolder -ChildPath "metadata-template.json"
$htmlTemplate               = Join-Path -Path $pandocFolder -ChildPath "story-template.html"
$officeTemplate             = Join-Path -Path $pandocFolder -ChildPath "story-template-office.md"
$ebookTemplate              = Join-Path -Path $pandocFolder -ChildPath "story-template-ebook.md"
$pdfTemplate                = Join-Path -Path $pandocFolder -ChildPath "pandoc-md-typst.template"

$docxReferenceFile          = Join-Path -Path $pandocFolder -ChildPath "pandoc-reference.docx"
$odtReferenceFile           = Join-Path -Path $pandocFolder -ChildPath "pandoc-reference.odt"

$epubCssFile                = Join-Path -Path $pandocFolder -ChildPath "style.css"
$fontsFolder                = Join-Path -Path $pandocFolder -ChildPath "fonts"
$modern735Font              = Join-Path -Path $fontsFolder  -ChildPath "Modern735W03Rom.ttf"
$coverFolder                = Join-Path -Path $pandocFolder -ChildPath "cover"
$coverTemplateFile          = Join-Path -Path $coverFolder  -ChildPath "CoverTemplate.png"
$defaultCoverArtFile        = Join-Path -Path $coverFolder  -ChildPath "DefaultCoverArt-Cape.png"

if (-not (Test-Path $processSubmissionLuaFilter -PathType Leaf)) {
  Write-Error "Error: File '$processSubmissionLuaFilter' does not exist."
  exit 1
}

if (-not (Test-Path $getMetadataJsonLuaFilter -PathType Leaf)) {
  Write-Error "Error: File '$getMetadataJsonLuaFilter' does not exist."
  exit 1
}

if (-not (Test-Path $customHRLuaFilter -PathType Leaf)) {
  Write-Error "Error: File '$customHRLuaFilter' does not exist."
  exit 1
}

if (-not (Test-Path $authorsLuaFilter -PathType Leaf)) {
  Write-Error "Error: File '$authorsLuaFilter' does not exist."
  exit 1
}

if (-not (Test-Path $websiteAdjustmentLuaFilter -PathType Leaf)) {
  Write-Error "Error: File '$websiteAdjustmentLuaFilter' does not exist."
  exit 1
}

if (-not (Test-Path $extractPrefaceLuaFilter -PathType Leaf)) {
  Write-Error "Error: File '$extractPrefaceLuaFilter' does not exist."
  exit 1
}

if (-not (Test-Path $headingFinderLuaFilter -PathType Leaf)) {
  Write-Error "Error: File '$headingFinderLuaFilter' does not exist."
  exit 1
}

if (-not (Test-Path $escapePlaintextLuaFilter -PathType Leaf)) {
  Write-Error "Error: File '$escapePlaintextLuaFilter' does not exist."
  exit 1
}

if (-not (Test-Path $metadataJsonTemplate -PathType Leaf)) {
  Write-Error "Error: File '$metadataJsonTemplate' does not exist."
  exit 1
}

if (-not (Test-Path $htmlTemplate -PathType Leaf)) {
  Write-Error "Error: File '$htmlTemplate' does not exist."
  exit 1
}

if (-not (Test-Path $officeTemplate -PathType Leaf)) {
  Write-Error "Error: File '$officeTemplate' does not exist."
  exit 1
}

if (-not (Test-Path $ebookTemplate -PathType Leaf)) {
  Write-Error "Error: File '$ebookTemplate' does not exist."
  exit 1
}

if (-not (Test-Path $pdfTemplate -PathType Leaf)) {
  Write-Error "Error: File '$pdfTemplate' does not exist."
  exit 1
}

if (-not (Test-Path $docxReferenceFile -PathType Leaf)) {
  Write-Error "Error: File '$docxReferenceFile' does not exist."
  exit 1
}

if (-not (Test-Path $odtReferenceFile -PathType Leaf)) {
  Write-Error "Error: File '$odtReferenceFile' does not exist."
  exit 1
}

if (-not (Test-Path $epubCssFile -PathType Leaf)) {
  Write-Error "Error: File '$epubCssFile' does not exist."
  exit 1
}

if (-not (Test-Path $fontsFolder -PathType Container)) {
  Write-Error "Error: Folder '$fontsFolder' does not exist."
  exit 1
}

if (-not (Test-Path $modern735Font -PathType Leaf)) {
  Write-Error "Error: File '$modern735Font' does not exist."
  exit 1
}

if (-not (Test-Path $coverTemplateFile -PathType Leaf)) {
  Write-Error "Error: File '$coverTemplateFile' does not exist."
  exit 1
}

if (-not (Test-Path $defaultCoverArtFile -PathType Leaf)) {
  Write-Error "Error: File '$defaultCoverArtFile' does not exist."
  exit 1
}

if (-not (Get-Command "pandoc" -ErrorAction SilentlyContinue)) {
  Write-Error "'pandoc' is not available in system PATH. Install Pandoc (https://pandoc.org/installing.html)."
  exit 1
}

if (-not (Get-Command "ebook-convert" -ErrorAction SilentlyContinue)) {
  Write-Error "'ebook-convert' is not available in system PATH. Install Calibre (https://manual.calibre-ebook.com)."
  exit 1
}

if (-not (Get-Command "typst" -ErrorAction SilentlyContinue)) {
  Write-Error "'typst' is not available in system PATH. Install Typst (https://github.com/typst/typst/releases/)."
  exit 1
}

if (-not (Get-Command "CoverGenerator.exe" -ErrorAction SilentlyContinue)) {
  Write-Error "'CoverGenerator.exe' is not available in system PATH. Releases available at https://github.com/LCFanfic/ArchiveAutomation/releases."
  exit 1
}

$extensionOne = [System.IO.Path]::GetExtension($InputFileOne).ToLower()
$extensionTwo = [System.IO.Path]::GetExtension($InputFileTwo).ToLower()

$graphicsExtensions = @(".png", ".jpg")

if (-not $InputFileTwo) {
  $storyfile = $InputFileOne
  $coverArt = $null
} elseif ($extensionOne -eq ".docx" -and $graphicsExtensions -contains $extensionTwo) {
  $storyfile = $InputFileOne
  $coverArt = $InputFileTwo
} elseif ($extensionTwo -eq ".docx" -and $graphicsExtensions -contains $extensionOne) {
  $storyfile = $InputFileTwo
  $coverArt = $InputFileOne
} else {
  Write-Error "Error: One file must be a DOCX and if a second file is provided, it must be a PNG or JPG."
  exit 1
}

$storyID = [System.IO.Path]::GetFileNameWithoutExtension($storyfile) -split " - " | Select-Object -First 1

if ($storyID.Length -gt 8) {
  Write-Error "Error: The story file name must contain a prefix part of up to eight charachters, separated from the remaining file name via ' - '."
  exit 1
}

if ($storyID -match "\s") {
  Write-Error "Error: The story file's prefix must not contain whitespace."
  exit 1
}

# For testing and scaling the iamge, use ImageMagick (https://imagemagick.org)

$storyMarkdown =       Join-Path -Path $TempFolder   -ChildPath "$storyID.md"
$metadataJson =        Join-Path -Path $TempFolder   -ChildPath "$storyID.json"
$inputOfficeMarkdown = Join-Path -Path $TempFolder   -ChildPath "$storyID-office.md"
$inputEbookMarkdown =  Join-Path -Path $TempFolder   -ChildPath "$storyID-ebook.md"
$ebookCover =          Join-Path -Path $TempFolder   -ChildPath "$storyID-cover.jpg"
$outputHtml =          Join-Path -Path $OutputFolder -ChildPath "html" | Join-Path -ChildPath "$storyID.html"
$outputDocx =          Join-Path -Path $OutputFolder -ChildPath "doc"  | Join-Path -ChildPath "$storyID.docx"
$outputOdt =           Join-Path -Path $OutputFolder -ChildPath "ooo"  | Join-Path -ChildPath "$storyID.odt"
$outputTxt =           Join-Path -Path $OutputFolder -ChildPath "text" | Join-Path -ChildPath "$storyID.txt"
$outputEpub =          Join-Path -Path $OutputFolder -ChildPath "epub" | Join-Path -ChildPath "$storyID.epub"
$outputMobi =          Join-Path -Path $OutputFolder -ChildPath "mobi" | Join-Path -ChildPath "$storyID.mobi"
$outputPdf =           Join-Path -Path $OutputFolder -ChildPath "pdf"  | Join-Path -ChildPath "$storyID.pdf"

New-Item -ItemType Directory -Force -Path (Split-Path -Path $outputHtml -Parent) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Path $outputDocx -Parent) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Path $outputOdt  -Parent) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Path $outputTxt  -Parent) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Path $outputEpub -Parent) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Path $outputMobi -Parent) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Path $outputPdf  -Parent) | Out-Null

Write-Output "Processing '$storyfile'..."

pandoc "$storyfile" --standalone -t markdown_strict -o "$storyMarkdown" --lua-filter="$processSubmissionLuaFilter" -M authorstable="$AuthorsFile" -M filename="$storyID"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing the story file via Pandoc failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}

pandoc "$storyMarkdown" --standalone -o "$metadataJson" --to plain --lua-filter="$getMetadataJsonLuaFilter" --template="$metadataJsonTemplate"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing the story file via Pandoc for metadata output failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}

$metadata = Get-Content -Raw "$metadataJson" | ConvertFrom-Json

if ($coverArt){
  $coverArtFile = $coverArt
}  else {
  $coverArtFile = $defaultCoverArtFile
}

&CoverGenerator.exe `
  --cover-template "$coverTemplateFile" `
  --font "$modern735Font" `
  --output "$ebookCover" `
  --title "$($metadata.title)" `
  --author "by $($metadata.'authornames-formatted')" `
  --publisher "Published on the Lois & Clark Fanfic Archive • $(([DateTime]$metadata.date).Year)" `
  --cover-art "$coverArtFile"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Generating the cover file failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}

&pandoc "$storyMarkdown" --standalone -o "$outputHtml" `
  --lua-filter="$authorsLuaFilter" `
  --lua-filter="$extractPrefaceLuaFilter" `
  --lua-filter="$headingFinderLuaFilter" `
  --lua-filter="$customHRLuaFilter" `
  --lua-filter="$websiteAdjustmentLuaFilter" `
  --template="$htmlTemplate"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing the story file via Pandoc for HTML output failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}
Write-Output "Created HTML format: '$outputHtml'."

# Use a temporary markdown file for structuring the output files
pandoc "$storyMarkdown" --standalone -o "$inputOfficeMarkdown" --lua-filter="$authorsLuaFilter" --template="$officeTemplate"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing for intermediate office format failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}

# Use a temporary markdown file for structuring the output files
pandoc "$storyMarkdown" --standalone -o "$inputEbookMarkdown" --lua-filter="$authorsLuaFilter" --lua-filter="$extractPrefaceLuaFilter" --lua-filter="$headingFinderLuaFilter" --template="$ebookTemplate"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing for intermediate office format failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}

pandoc "$inputOfficeMarkdown" --standalone -o "$outputDocx" --reference-doc="$docxReferenceFile" --lua-filter="$customHRLuaFilter"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing the story file via Pandoc for DOCX output failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}
Write-Output "Created DOCX format: '$outputDocx'."

pandoc "$inputOfficeMarkdown" --standalone -o "$outputOdt" --reference-doc="$odtReferenceFile" --lua-filter="$customHRLuaFilter"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing the story file via Pandoc for ODT output failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}
Write-Output "Created ODT format:  '$outputOdt'."

pandoc "$inputOfficeMarkdown" --standalone -o "$outputTxt" -t plain -f markdown-smart --columns=65 --lua-filter="$customHRLuaFilter" --lua-filter="$escapePlaintextLuaFilter"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing the story file via Pandoc for TXT output failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}
Write-Output "Created TXT format:  '$outputTxt'."

pandoc "$inputEbookMarkdown"  --standalone -o "$outputEpub" --lua-filter="$customHRLuaFilter" --css="$epubCssFile" --epub-cover-image="$ebookCover" --epub-title-page=false
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing the story file via Pandoc for EPUB output failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}
Write-Output "Created EPUB format: '$outputEpub'."

# Convert to to kindle:
$calibre_output = ebook-convert "$outputEpub" "$outputMobi" | Out-String
if ($LASTEXITCODE -ne 0) {
  Write-Output $calibre_output
  Write-Error "Error: Processing the story file via Pandoc for EPUB output failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}
Write-Output "Created MOBI format: '$outputMobi'."

# use TYPST for PDF
$env:TYPST_FONT_PATHS="$fontsFolder"
pandoc "$storyMarkdown"  -o "$outputPdf" --wrap=none --pdf-engine=typst --template="$pdfTemplate" --lua-filter="$extractPrefaceLuaFilter"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error: Processing the story file via Pandoc for PDF output failed with exit code $LASTEXITCODE."
  exit $LASTEXITCODE
}
Write-Output "Created PDF format:  '$outputPdf'."

Move-Item -Path $storyfile -Destination $ArchiveFolder -Force
$coverartDestinationPath = Join-Path -Path $ArchiveFolder -ChildPath "$storyID$([System.IO.Path]::GetExtension($coverArt))"
if ($coverArt) {
  Move-Item -Path $coverArt -Destination $coverartDestinationPath -Force
}
Move-Item -Path $storyMarkdown -Destination $ArchiveFolder -Force
Move-Item -Path $metadataJson -Destination $ArchiveFolder -Force

Write-Output "Moved story files to '$ArchiveFolder'."
