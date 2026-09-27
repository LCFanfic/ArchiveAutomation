# merge-story-jsons.ps1 -- append the submission files in -ArchiveFolder to stories.json.
#
# Usage: .\merge-story-jsons.ps1 [-ArchiveFolder dir] [-AuthorsFile authors.json] [-StoriesFile stories.json] [-Apply]
#
# Run without -Apply for a dry run. Nothing is written if any file fails to
# convert or any story is already in stories.json.

param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_ -PathType Container}, ErrorMessage = "Folder does not exist.")]
  [string]$ArchiveFolder = (Join-Path $PSScriptRoot 'archive'),

  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_ -PathType Leaf}, ErrorMessage = "File does not exist.")]
  [string]$AuthorsFile = (Join-Path $PSScriptRoot 'authors.json'),

  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_ -PathType Leaf}, ErrorMessage = "File does not exist.")]
  [string]$StoriesFile  = (Join-Path $PSScriptRoot 'stories.json'),

  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# The minimum JSON requires, non-ASCII left as itself, matching the file.
function ConvertTo-JsonString([string]$s) {
  if ($null -eq $s) {
    $s = ''
  }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  foreach ($ch in $s.ToCharArray()) {
    switch ($ch) {
      '"'  { [void]$sb.Append('\"');  break }
      '\'  { [void]$sb.Append('\\');  break }
      "`b" { [void]$sb.Append('\b');  break }
      "`f" { [void]$sb.Append('\f');  break }
      "`n" { [void]$sb.Append('\n');  break }
      "`r" { [void]$sb.Append('\r');  break }
      "`t" { [void]$sb.Append('\t');  break }
      default {
        if ([int]$ch -lt 0x20) {
          [void]$sb.Append(('\u{0:x4}' -f [int]$ch))
        } else {
          [void]$sb.Append($ch)
        }
      }
    }
  }
  [void]$sb.Append('"')
  return $sb.ToString()
}

# ------------------------------------------------------------ author emails ---

$authorsPayload = [System.IO.File]::ReadAllText($AuthorsFile, $utf8) | ConvertFrom-Json
$slugsByEmail = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($prop in $authorsPayload.PSObject.Properties) {
  $emails = @()
  if ($prop.Value.email) {
    $emails += $prop.Value.email
  }
  if ($prop.Value.'email-secondary') {
    $emails += @($prop.Value.'email-secondary')
  }
  foreach ($e in $emails) {
    $key = $e.Trim()
    if ($key -eq '') {
      continue
    }
    if (-not $slugsByEmail.ContainsKey($key)) {
      $slugsByEmail[$key] = New-Object System.Collections.Generic.List[string]
    }
    if (-not $slugsByEmail[$key].Contains($prop.Name)) {
      $slugsByEmail[$key].Add($prop.Name)
    }
  }
}

# ----------------------------------------------------------- build records ---

$json = [System.IO.File]::ReadAllText($StoriesFile, $utf8)
if ($json.Contains("`r`n")) {
  $nl = "`r`n"
} else {
  $nl = "`n"
}
$uploadDate = Get-Date
$storiesFileName = Split-Path -Path $StoriesFile -Leaf

$errors = New-Object System.Collections.Generic.List[string]
$blocks = New-Object System.Collections.Generic.List[string]
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)

foreach ($file in (Get-ChildItem -Path $ArchiveFolder -Filter *.json -File | Sort-Object Name)) {
  if ($file.CreationTime.Date -ne $uploadDate.Date) {
    continue
  }
  try {
    $data = [System.IO.File]::ReadAllText($file.FullName, $utf8) | ConvertFrom-Json
  } catch {
    $errors.Add("$($file.Name): invalid JSON")
    continue
  }

  $name = [string]$data.filename
  if ($name -notmatch '^[A-Za-z0-9_-]+$') {
    $errors.Add("$($file.Name): bad filename '$name'")
    continue
  }
  if (-not $seen.Add($name)) {
    $errors.Add("$($file.Name): '$name' appears twice in the input")
    continue
  }
  if ($json -match ('"filename":\s*"' + [regex]::Escape($name) + '"')) {
    $errors.Add("$($file.Name): '$name' is already in $storiesFileName")
    continue
  }

  $formats = @("txt", "doc", "odt", "pdf", "epub", "mobi")

  $submissionDate = [string]$data.date
  if ($submissionDate -notmatch '^(\d{4})-\d{2}-\d{2}$') {
    $errors.Add("$($file.Name): date '$submissionDate' is not yyyy-mm-dd")
    continue
  }

  $rating = ([string]$data.rating) -replace '-', ''
  if ($rating -cnotin @('G', 'PG', 'PG13')) {
    $errors.Add("$($file.Name): rating '$($data.rating)' is not G, PG or PG-13")
    continue
  }

  $words = ([string]$data.length.words) -replace '[^0-9]', ''
  if ($words -eq '') {
    $errors.Add("$($file.Name): no word count")
    continue
  }
  if ([string]$data.length.text -notmatch '^\s*([\d,]+)\s*kB\s*$') {
    $errors.Add("$($file.Name): size '$($data.length.text)' is not in kB")
    continue
  }
  $sizeKb = $Matches[1] -replace ',', ''

  $slugs = New-Object System.Collections.Generic.List[string]
  foreach ($a in @($data.authors)) {
    $email = ([string]$a.email).Trim()
    if (-not $slugsByEmail.ContainsKey($email)) {
      $errors.Add("$($file.Name): no author with email '$email' ($($a.name))")
      continue
    }
    $matched = $slugsByEmail[$email]
    if ($matched.Count -gt 1) {
      $errors.Add("$($file.Name): email '$email' belongs to $($matched -join ', ')")
      continue
    }
    $slugs.Add($matched[0])
  }
  if ($slugs.Count -eq 0) {
    $errors.Add("$($file.Name): no authors resolved")
    continue
  }
  if ($slugs.Count -ne @($data.authors).Count) {
    continue
  }

  $title = [string]$data.title
  $article = $null
  if ($title -cmatch '^(A|An|The)\s+(.+)$') {
    $article = $Matches[1]
    $title = $Matches[2]
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('  "filename": ' + (ConvertTo-JsonString $name))
  $lines.Add('  "formats": [' + (($formats | ForEach-Object { ConvertTo-JsonString $_ }) -join ', ') + ']')
  $lines.Add('  "url-archive": ' + (ConvertTo-JsonString "http://www.lcfanfic.com/stories/$($uploadDate.Year)/html/$name.html"))
  $lines.Add('  "filesize-kb": ' + [int]$sizeKb)
  $lines.Add('  "word-count": ' + [int]$words)
  $lines.Add('  "title": ' + (ConvertTo-JsonString $title))
  if ($article) {
    $lines.Add('  "title-article": ' + (ConvertTo-JsonString $article))
  }
  $lines.Add('  "authors": [' + (($slugs | ForEach-Object { ConvertTo-JsonString $_ }) -join ', ') + ']')
  $lines.Add('  "summary": ' + (ConvertTo-JsonString ([string]$data.summary)))
  $lines.Add('  "submission-date": ' + (ConvertTo-JsonString $submissionDate))
  $lines.Add('  "upload-date": ' + (ConvertTo-JsonString $uploadDate.ToString('yyyy-MM-dd')))
  $lines.Add('  "rating": ' + (ConvertTo-JsonString $rating))
  $lines.Add('  "categories": []')

  $blocks.Add(' ' + (ConvertTo-JsonString $name) + ": {$nl" + ($lines -join ",$nl") + "$nl }")
}

if ($errors.Count -gt 0) {
  Write-Host 'NOTHING WRITTEN:'
  foreach ($e in $errors) {
    Write-Host "  $e"
  }
  throw "$($errors.Count) problem(s) in $ArchiveFolder."
}
if ($blocks.Count -eq 0) {
  Write-Host "No .json files in $ArchiveFolder that have been created today."
  return
}

# ------------------------------------------------------------------- splice ---

$idx = $json.LastIndexOf('}')
if ($idx -lt 0) {
  throw "$outLeaf does not end with a closing brace."
}
$head = $json.Substring(0, $idx).TrimEnd("`r", "`n", ' ')
if (-not $head.EndsWith('}')) {
  throw "Unexpected tail before the closing brace: [$($head.Substring([Math]::Max(0, $head.Length - 40)))]"
}
$updated = $head + ",$nl" + ($blocks -join ",$nl") + "$nl}" + $json.Substring($idx + 1)

if (-not $Apply) {
  Write-Host '--- DRY RUN, nothing written. ---'
  foreach ($b in $blocks) {
    Write-Host $b
  }
  Write-Host ''
  Write-Host 'Re-run with -Apply to write.'
  return
}

[System.IO.File]::WriteAllText($StoriesFile, $updated, $utf8)
Write-Host "Appended $($blocks.Count) stories to '$StoriesFile'."
