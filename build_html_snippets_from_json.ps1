param (
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

$pandocFolder = Join-Path -Path $PSScriptRoot -ChildPath "StoryIndex"

$htmlByFilenameTemplate = Join-Path -Path $pandocFolder -ChildPath "byfilename-template.html"
$htmlByAuthorTemplate   = Join-Path -Path $pandocFolder -ChildPath "byauthor-template.html"
$htmlByTitleTemplate    = Join-Path -Path $pandocFolder -ChildPath "bytitle-template.html"
$htmlIndexTemplate      = Join-Path -Path $pandocFolder -ChildPath "index-template.html"

$tempOutputFile         = Join-Path -Path $TempFolder -ChildPath "html.tmp"

$outputHtmlByFilename   = Join-Path -Path $OutputFolder -ChildPath "snippet_byFilename.html"
$outputHtmlByAuthor     = Join-Path -Path $OutputFolder -ChildPath "snippet_byAuthor.html"
$outputHtmlByTitle      = Join-Path -Path $OutputFolder -ChildPath "snippet_byTitle.html"
$outputHtmlByDate       = Join-Path -Path $OutputFolder -ChildPath "snippet_byDate.html"
$outputHtmlWhatsNew     = Join-Path -Path $OutputFolder -ChildPath "snippet_WhatsNew.html"
$outputHtmlIndex        = Join-Path -Path $OutputFolder -ChildPath "snippet_Index.html"


if (-not (Get-Command "pandoc" -ErrorAction SilentlyContinue)) {
  Write-Error "'pandoc' is not available in system PATH. Install Pandoc (https://pandoc.org/installing.html)."
  exit 1
}

if (-not (Test-Path $htmlByFilenameTemplate -PathType Leaf)) {
  Write-Error "Error: File '$htmlByFilenameTemplate' does not exist."
  exit 1
}

if (-not (Test-Path $htmlByAuthorTemplate -PathType Leaf)) {
  Write-Error "Error: File '$htmlByAuthorTemplate' does not exist."
  exit 1
}

if (-not (Test-Path $htmlByTitleTemplate -PathType Leaf)) {
  Write-Error "Error: File '$htmlByTitleTemplate' does not exist."
  exit 1
}

$files = Get-ChildItem -Path $ArchiveFolder -Filter *.json | Where-Object {
  $_.CreationTime.Date -eq (Get-Date).Date
}

$jsonObjects = $files | ForEach-Object {
  Get-Content $_.FullName | Out-String | ConvertFrom-Json
}

function Remove-Articles {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Value
  )

  return $Value -replace '^(A|An|The)\s+', ''
}

# Build filename list (sorted by filename)
$byFilename = $jsonObjects | Sort-Object filename

# Build title list (sorted by title, ignoring leading A, An, The)
$byTitle = $jsonObjects | Sort-Object @{Expression={ Remove-Articles -Value $_.title.ToLower() }}

# Build author list (one entry per author, sorted by url)
$authorEntries = @()
foreach ($obj in $jsonObjects) {
  foreach ($author in $obj.authors) {
    $entry = [PSCustomObject]@{
      author = $author
      story  = $obj
    }
    $authorEntries += $entry
  }
}
$byAuthor = $authorEntries | Sort-Object @{Expression={ $_.author.url }}, @{Expression={ Remove-Articles -Value $_.story.title.ToLower() }}

function Convert-StoryMetadataToHtmlSnippet {
  param (
    [Parameter(Mandatory=$true)]
    $StoryMetadata,
    [Parameter(Mandatory=$true)]
    [string]$TemplatePath
  )

  $filename = $StoryMetadata.filename
  $title = $StoryMetadata.title
  $authors_formatted = $StoryMetadata.'authornames-formatted'
  $length_words = $StoryMetadata.length.words
  $length_text = $StoryMetadata.length.text
  $year = Get-Date -Format yyyy
  $summary = $StoryMetadata.summary
  $body = "Dummy content for pandoc since we use metadata for the summary to avoid block-level rendering."

  $body | pandoc --standalone --to=html --eol=lf `
    --template="$TemplatePath" `
    --metadata=filename="$filename" `
    --metadata=title="$title" `
    --metadata=authors_formatted="$authors_formatted" `
    --metadata=length_words="$length_words" `
    --metadata=length_text="$length_text" `
    --metadata=year="$year" `
    --metadata=is_multi_author=$($StoryMetadata.authors.Count -gt 1) `
    --metadata=summary="$summary" `
    --output="$tempOutputFile" `
    --wrap=preserve

  if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: Processing story '$filename.json' via Pandoc for HTML output failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
  }
  return Get-Content -Path $tempOutputFile -Raw
}

if (Test-Path $outputHtmlByFilename) {
  Remove-Item -Path $outputHtmlByFilename -Force
}
New-Item -Path $outputHtmlByFilename -ItemType File -Force | Out-Null
foreach ($story in $byFilename) {
  $sortableFilename = $story.filename.ToLower()
  $indexKey = $sortableFilename[0]
  if ($indexKey -match '[0-9]') {
    $indexKey = '1'
  } elseif ($indexKey -match '[s]') {
    $indexKey += ($sortableFilename -match 's[i-z].*' ? 'i' : 'a')
  } elseif ($indexKey -match '[t]') {
    $indexKey += ($sortableFilename -match 't[r-z].*' ? 'r' : 'a')
  }
  Add-Content -Path $outputHtmlByFilename -Value "<!-- filename_$indexKey.htm -->"
  $output = Convert-StoryMetadataToHtmlSnippet -StoryMetadata $story -TemplatePath $htmlByFilenameTemplate
  Add-Content -Path $outputHtmlByFilename -Value $output
}

if (Test-Path $outputHtmlByTitle) {
  Remove-Item -Path $outputHtmlByTitle -Force
}
New-Item -Path $outputHtmlByTitle -ItemType File -Force | Out-Null
foreach ($story in $byTitle) {
  $sortableTitle = Remove-Articles -Value $story.title.ToLower()
  $indexKey = $sortableTitle[0]
  if ($indexKey -match '[0-9]') {
    $indexKey = '1'
  } elseif ($indexKey -match '[c]') {
    $indexKey += ($sortableTitle -match 'c[l-z].*' ? 'i' : 'a')
  } elseif ($indexKey -match '[l]') {
    $indexKey += ($sortableTitle -match 'l[o-z].*' ? 'o' : 'a')
  } elseif ($indexKey -match '[s]') {
    $indexKey += ($sortableTitle -match 's[o-z].*' ? 'o' : 'a')
  } elseif ($indexKey -match '[t]') {
    $indexKey += ($sortableTitle -match 't[i-z].*' ? 'i' : 'a')
  }
  Add-Content -Path $outputHtmlByTitle -Value "<!-- title_$indexKey.htm -->"
  $output = Convert-StoryMetadataToHtmlSnippet -StoryMetadata $story -TemplatePath $htmlByTitleTemplate
  Add-Content -Path $outputHtmlByTitle -Value $output
}

if (Test-Path $outputHtmlByAuthor) {
  Remove-Item -Path $outputHtmlByAuthor -Force
}
New-Item -Path $outputHtmlByAuthor -ItemType File -Force | Out-Null
foreach ($item in $byAuthor) {
  $sortableAuthor = $item.author.name.ToLower()
  $indexKey = $sortableAuthor[0]
  if ($indexKey -match '[0-9]') {
    $indexKey = '1'
  } elseif ($indexKey -match '[b]') {
    $indexKey += ($sortableAuthor -match 'b[r-z].*' ? 'r' : 'a')
  } elseif ($indexKey -match '[s]') {
    $indexKey += ($sortableAuthor -match 's[m-z].*' ? 'm' : 'a')
  }
  Add-Content -Path $outputHtmlByAuthor -Value "<!-- author_$indexKey.htm -->"
  $output = Convert-StoryMetadataToHtmlSnippet -StoryMetadata $item.story -TemplatePath $htmlByAuthorTemplate
  Add-Content -Path $outputHtmlByAuthor -Value $output
}

if (Test-Path $outputHtmlByDate) {
  Remove-Item -Path $outputHtmlByDate -Force
}
New-Item -Path $outputHtmlByDate -ItemType File -Force | Out-Null
foreach ($story in $byTitle) {
  $output = Convert-StoryMetadataToHtmlSnippet -StoryMetadata $story -TemplatePath $htmlByTitleTemplate
  Add-Content -Path $outputHtmlByDate -Value $output
}

if (Test-Path $outputHtmlWhatsNew) {
  Remove-Item -Path $outputHtmlWhatsNew -Force
}
Copy-Item -Path $outputHtmlByDate -Destination $outputHtmlWhatsNew -Force

if (Test-Path $outputHtmlIndex) {
  Remove-Item -Path $outputHtmlIndex -Force
}
New-Item -Path $outputHtmlIndex -ItemType File -Force | Out-Null

$humanizedNumbers = @(
  'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
  'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen', 'Twenty'
)

foreach ($stories in $byTitle | Group-Object -Property 'authornames-formatted' | Sort-Object -Property Count -Descending) {
  Add-Content -Path $outputHtmlIndex -Value "<p style=`"font-size: 110%; padding-bottom: 1em;`">"
  $storyCount = $stories.Count
  $storySummary  = ($storyCount -lt $humanizedNumbers.Count) ? $humanizedNumbers[$storyCount] : "$storyCount"
  $storySummary += ($stories.Group[0].authors.Count -gt 1) ? " multi-authored" : ""
  $storySummary += ($storyCount -eq 1) ? " story" : " stories"
  $storySummary += " by <b>"
  $storySummary += $stories.Group[0].'authornames-formatted'
  $storySummary += "</b>:<br>"
  Add-Content -Path $outputHtmlIndex -Value $storySummary
  foreach ($story in $stories.Group) {
    $output = Convert-StoryMetadataToHtmlSnippet -StoryMetadata $story -TemplatePath $htmlIndexTemplate
    Add-Content -Path $outputHtmlIndex -Value $output
  }
  Add-Content -Path $outputHtmlIndex -Value "</p>"
}

Write-Host "HTML snippets generated successfully:"
Write-Host " - $outputHtmlByFilename"
Write-Host " - $outputHtmlByAuthor"
Write-Host " - $outputHtmlByTitle"
Write-Host " - $outputHtmlByDate"
Write-Host " - $outputHtmlWhatsNew"
Write-Host " - $outputHtmlIndex"