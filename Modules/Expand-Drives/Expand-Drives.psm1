function Expand-Drives ()
{
    [CmdletBinding()]
    # The servers parameter is mandatory and is an array. It takes a list of servers separated by commas.
    Param(
    [Parameter (Mandatory=$true)]
    [string[]]$servers
    )
    $creds = Get-Credential
    foreach($server in $servers)
    {
        $ses = New-PSSession $server -Credential $creds
        Invoke-Command -Session $ses -ScriptBlock {
            Write-Host "Expanding C and D drives..."
            "rescan", "select volume C", "extend" | diskpart
            Write-Host "C drive extended" -ForegroundColor Green -BackgroundColor Black
            "select volume D", "extend", "exit" | diskpart
            Write-Host "D drive extended" -ForegroundColor Green -BackgroundColor Black
        }
        Get-PSSession | Remove-PSSession
    }
}