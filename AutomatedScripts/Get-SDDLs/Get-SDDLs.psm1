# Script to extract SDDL strings for S3 Edge configuration
# Paths to check
$paths = @(
    "\\path\to\file",
    "\\path\to\file",
    "\\path\to\file"
)

# Function to get SDDL for a path
function Get-PathSDDL {
    param(
        [string]$Path
    )

    Write-Host "Processing path: $Path" -ForegroundColor Green
    Write-Host "=" * 50

    # Check if path exists
    if (-not (Test-Path $Path)) {
        Write-Warning "Path '$Path' does not exist. Skipping..."
        return
    }

    try {
        # Get the ACL and extract SDDL
        $acl = Get-Acl $Path
        $sddl = $acl.Sddl

        # Determine if it's a file or directory
        $item = Get-Item $Path
        $type = if ($item.PSIsContainer) { "Directory" } else { "File" }
        $configKey = if ($item.PSIsContainer) { "dir_sddl" } else { "file_sddl" }

        # Map to corresponding S3 bucket
        $bucketName = switch -Wildcard ($Path) {
            "*Dev*" { "s3bucketname" }
            "*Cert*" { "s3bucketname" }
            "*Prod*" { "s3bucketname" }
            default { "unknown" }
        }

        Write-Host "Type: $type"
        Write-Host "S3 Bucket: $bucketName"
        Write-Host "Config Key: $configKey"
        Write-Host "SDDL String:"
        Write-Host $sddl -ForegroundColor Yellow
        Write-Host ""

        # Return structured data
        return @{
            Path = $Path
            Type = $type
            ConfigKey = $configKey
            BucketName = $bucketName
            SDDL = $sddl
        }
    }
    catch {
        Write-Error "Failed to get SDDL for '$Path': $($_.Exception.Message)"
    }
}

# Main execution
Write-Host "SDDL String Extraction for S3 Edge Configuration" -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host ""

$results = @()

foreach ($path in $paths) {
    $result = Get-PathSDDL -Path $path
    if ($result) {
        $results += $result
    }
    Write-Host ""
}

# Summary output for easy copying to S3 Edge configuration
if ($results.Count -gt 0) {
    Write-Host "SUMMARY - S3 Edge Configuration Values:" -ForegroundColor Cyan
    Write-Host "=" * 50

    foreach ($result in $results) {
        Write-Host "S3 Bucket: $($result.BucketName)" -ForegroundColor White
        Write-Host "Path: $($result.Path)"
        Write-Host "$($result.ConfigKey): $($result.SDDL)"
        Write-Host ""
    }
}