# Function to process files in a directory using multi-threading
<#function Check-FileHash {
    param (
        [string]$DirectoryPath,
        [int]$MaxThreads = 32
    )
    $jobs = @()
    $DirectoryPath = Read-Host "Please enter the directory path"
    $files = Get-ChildItem -Path $DirectoryPath -File -Recurse

    foreach ($file in $files) {
        # Wait for a job to complete if the maximum number of threads is reached
        while ($jobs.Count -ge $MaxThreads) {
            $completedJob = $jobs | Wait-Job -Any
            $result = Receive-Job -Job $completedJob
            $result | Format-Table -AutoSize
            $result | Export-Csv -Path C:\temp\Check-FileHash.csv -Append
            Remove-Job -Job $completedJob
            $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
        }
        # Start a background job to calculate the hash
        $fullpath = "$($file.directory)\$file"
        $brokenfile = ""
        Start-ThreadJob -ScriptBlock {
            try {
                Get-FileHash -Path $Using:FullPath -Algorithm MD5 -ErrorAction Stop | select path, Hash
            } catch {
               "Could not access $Using:FullPath"
            }
        } -ThrottleLimit $MaxThreads
    }
    # Wait for any remaining jobs to complete
    while ($jobs.Count -gt 0) {
        $completedJob = $jobs | Wait-Job -Any
        $result = Receive-Job -Job $completedJob
        $result | Format-Table -AutoSize
        $result | Export-Csv -Path C:\temp\Check-FileHash.csv -Append
        Remove-Job -Job $completedJob
        $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
    }

}#>
function Check-FileHash {
    $directorypath = read-host "Enter the drive letter"
    $directories = Get-ChildItem -Path $DirectoryPath -Directory
    $jobs = @()
    $csvFilePath = "D:\logs\successfulHashes.csv"
    Write-Host "Successful Hash file will be located at $csvFilepath"
    $failurepath = "D:\logs\Failedhashes.csv"
    Write-host "Failed Hash file will be located at $failurepath"
    $directoryindex = 0
    foreach ($directory in $directories)
    {
        if ($directory.name -like "*22922*")
        {
            continue
        }
        Write-Host "Beginning work on $($directory.name) ($directoryindex of $($directories.count))"
        $files = Get-ChildItem -Path $directory.fullname -File -Recurse
        $fileIndex = 0
        $directoryindex++
        while ($fileIndex -lt $files.Count -or $jobs.Count -gt 0) {
            # Check if there are available slots for new jobs
            if ($jobs.Count -lt 1000 -and $fileIndex -lt $files.Count) {
                $file = $files[$fileIndex]
                $fileIndex++
                
                # Start a new background job to calculate the hash
                $fullPath = "$($file.Directory)\$file"
                $job = Start-ThreadJob -ScriptBlock {
                    try {
                        $result = Get-FileHash -Path $Using:fullPath -Algorithm MD5 -ErrorAction Stop
                        $result.Hash
                    } catch {
                        "Unable to access $Using:fullPath"
                    }
                } -ThrottleLimit 300
                $jobs += @($job)
            }
                    # Check for completed jobs
            $completedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
            foreach ($completedJob in $completedJobs) 
            {
                $result = Receive-Job -Job $completedJob
                if ($result -like "*Unable to access*")
                {
                    $result | out-file -FilePath $failurepath -append
                }
                else
                {
                    $result | Out-File -FilePath $csvFilePath -Append
                }
                Remove-Job -Job $completedJob
                $jobs = $jobs | Where-Object { $_ -ne $completedJob }
            }
        }
        Write-Host "Cleaning up the variables..."
        $files = $null
        [system.gc]::Collect()
    }
}