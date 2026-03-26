<#
.SYNOPSIS
    Retrieves and displays log files from multiple monitoring scripts on the scriptingserver.example.com server.

.DESCRIPTION
    This script establishes a remote session to the scriptingserver.example.com server and retrieves log contents 
    from various monitoring scripts. It provides a consolidated view of all script execution logs.

.NOTES
    Author: Coby Carter
    Last Updated: 11/22/2024
    Change History:
    11/22/2024 - Initial script creation

.EXAMPLE
    Check-ScriptLogs

    Connects to scriptingserver.example.com server and displays contents of all monitoring script logs in sequence, 
    providing a complete overview of script execution results.
#>
function Check-ScriptLogs()
{
    $Creds = Get-Credential
    $ses = New-PSSession -ComputerName scriptingserver.example.com -Credential $Creds
    Invoke-Command -Session $ses -ScriptBlock {
        Write-Host ""
        Write-Host "Example Script Log 1:"
        Get-Content "C:\Scripts\Logs\Check-ExampleScript1.txt"
        Write-Host ""
        Write-Host "Example Script Log 2:"
        Get-Content "C:\Scripts\Logs\Check-ExampleScript2.txt"
        Write-Host ""
        Write-Host "Example Script Log 3:"
        Get-Content "C:\Scripts\Logs\Check-ExampleScript3.txt"
        Write-Host ""
        Write-Host "Example Script Log 4:"
        Get-Content "C:\Scripts\Logs\Check-ExampleScript4.txt"
    }
}