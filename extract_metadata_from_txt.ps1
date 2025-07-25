# Define the file path
$filePath = "sample.txt"

# Read the file contents
$content = Get-Content $filePath -Raw

# Extract data using regex patterns
$title = $content | Select-String "^(.*?)(?=\nby)"
$authorMatch = $content | Select-String "by (.*?) \((.*?)\)"
$rating = $content | Select-String "Rated: (\S+)"
$submittedMatch = $content | Select-String "Submitted: (\w+) (\d+)"
$summaryMatch = $content | Select-String "Summary:(.*?)Story Size:" -Raw
$storySizeMatch = $content | Select-String "Story Size: (\d+) words \((\d+)Kb as text\)"

# Extract specific values
$title = $title.Matches.Groups[1].Value
$author = $authorMatch.Matches.Groups[1].Value
$email = $authorMatch.Matches.Groups[2].Value
$rating = $rating.Matches.Groups[1].Value
$month = $submittedMatch.Matches.Groups[1].Value
$year = $submittedMatch.Matches.Groups[2].Value
$summary = $summaryMatch.Matches.Groups[1].Value.Trim()
$wordCount = $storySizeMatch.Matches.Groups[1].Value
$bytes = $storySizeMatch.Matches.Groups[2].Value

# Create a PowerShell object
$result = [PSCustomObject]@{
    Title     = $title
    Author    = $author
    Email     = $email
    Rating    = $rating
    Month     = $month
    Year      = $year
    Summary   = $summary
    WordCount = $wordCount
    Bytes     = $bytes
}

# Convert the object to JSON
$jsonOutput = $result | ConvertTo-Json -Depth 2

# Save JSON to a file
$jsonOutput | Out-File "output.json"

# Display JSON
Write-Output $jsonOutput
