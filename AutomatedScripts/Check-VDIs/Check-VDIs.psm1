function Check-VDIs {
    <#
    .SYNOPSIS
    Searches for files with a specific extension under a user directory on a remote computer's C$ share.
    
    .PARAMETER ComputerName
    The name or IP address of the remote computer to check.
    
    .PARAMETER Username
    The username to check in the Users directory.
    
    .PARAMETER FileType
    The file extension to search for (e.g., ".xlsx", ".docx", ".pdf").
    
    .PARAMETER Credential
    Optional. Admin credentials for accessing the remote computer. If not provided, you will be prompted.
    
    .EXAMPLE
    Check-VDIs -ComputerName "SERVER01" -Username "jdoe" -FileType ".xlsx"
    
    .EXAMPLE
    $cred = Get-Credential
    Check-VDIs -ComputerName "SERVER01" -Username "jdoe" -FileType ".docx" -Credential $cred
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [string]$FileType,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    # Prompt for admin credentials if not provided
    if (-not $Credential) {
        $Credential = Get-Credential -Message "Enter admin credentials for $ComputerName"
        
        if (-not $Credential) {
            Write-Error "No credentials provided."
            return
        }
    }
    
    # Construct the UNC path to the user directory
    $RemotePath = "\\$ComputerName\C$\Users\$Username"
    
    Write-Host "Searching for '$FileType' files in: $RemotePath"
    
    try {
        # Use Invoke-Command to run the search on the remote machine
        $ScriptBlock = {
            param($UserPath, $FileType)
            
            $Files = Get-ChildItem -Path $UserPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq $FileType }
            $Results = @()
            
            foreach ($File in $Files) {
                $Results += $File.FullName
            }
            
            return @{
                Found = ($Results.Count -gt 0)
                Files = $Results
                Count = $Results.Count
            }
        }
        
        $UserPath = "C:\Users\$Username"
        $Result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $UserPath, $FileType
        
        if ($Result.Found) {
            Write-Host "Found $($Result.Count) '$FileType' file(s):" -ForegroundColor Green
            foreach ($FilePath in $Result.Files) {
                Write-Host "  $FilePath" -ForegroundColor Green
            }
        } else {
            Write-Host "No '$FileType' files found under C:\Users\$Username" -ForegroundColor Yellow
        }
        
        return $Result.Files
    }
    catch {
        Write-Error "Failed to search on $ComputerName : $($_.Exception.Message)"
        return @()
    }
}

