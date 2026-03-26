<#
.SYNOPSIS
    Manages printer configurations across print servers including additions, modifications, and driver updates.

.DESCRIPTION
    This script handles all printer management tasks including adding new printers, updating existing 
    printer configurations, changing printer names, and managing printer drivers. It works across 
    multiple print servers simultaneously and handles port creation, driver assignment, and sharing 
    settings.

.NOTES
    Author: Coby Carter
    Last Updated: 02/12/2020

.EXAMPLE
    Change-Printer

    Launches interactive printer management wizard that guides through printer configuration process. 
    Will prompt for credentials and necessary printer information based on selected operation.
#>

function Change-Printer()
{
    $creds = Get-Credential
    Get-PSSession | Remove-PSSession
    New-PSSession -ComputerName printserver1.example.com -Credential $creds
    New-PSSession -ComputerName printserver2.example.com -Credential $creds
    Clear-Host
    $sessions = Get-PSSession
    $newprinter = Read-Host "Is this a new printer to be added to the servers? y/n"
    if ($newprinter -eq 'n')
    {
        $changeprinter = Read-Host "Will this printer be a different model? y/n"
    }
    else 
    {
        $changeprinter = $null
    }
    $printername = Read-Host "Printer name"
    $IPAddress = Read-Host "IP Address"
    $newname = $null
    if ($newprinter -eq 'n')
    {
        $newnamechoice = Read-Host "Will this printer need a new name? y/n"
        if ($newnamechoice -eq 'y')
        {
            $newname = Read-Host "New Name"
        }
    }
    <#
    This is an interesting problem. I can't find the drivers by name for whatever reason
    but I can find them by just wildcarding the model number. Since model numbers are
    almost always unique, I figure this is identifying enough to find the driver we need
    #>
    if (($newprinter -eq 'y') -or ($changeprinter -eq 'y'))
    {
        $model = Read-Host "Model number"
    }
    else 
    {
        $model = $null
    }
    
    $location = Read-Host "Location"
    if (($newprinter -eq 'n') -and ($newnamechoice -eq 'y'))
    {
        Write-Host "Pulling current comment for use in updated comment. If empty, you will need to look at the driver and manually enter the comment."
        Invoke-Command -Session $sessions[0] -ScriptBlock {
            get-printer $Using:printername | select comment
        }
    }
    $Comment = Read-Host "Comment"
    foreach ($s in $sessions)
    {
        Invoke-Command -Session $s -ScriptBlock {
            if (($Using:newprinter -eq 'y') -or ($Using:changeprinter -eq 'y'))
            {
                $driver = get-printerdriver | select name | where name -like "*$Using:model*"
                $driver = $driver.name
                # Occasionally, there will be multiple driver names with very subtle differences, like a dash or a slash. This will just get one of those drivers.
                if ($driver -is [array])
                {
                    $driver = $driver[0]
                }
            }
            else 
            {
                $driver = get-printer $Using:printername | select drivername -Unique
                $driver = $driver.drivername    
            }
            Write-Host "`n`rUpdating $env:COMPUTERNAME..." -ForegroundColor Yellow
            # Set-Printer if it's not new, but add it if it is.
            if ($Using:newprinter -eq 'n')
            {
                Write-Host "Updating Printer Info..."
                Write-Host "Checking and updating port..."
                $port = Get-PrinterPort | select name | where name -like "*$Using:IPAddress*"
                if ($port -eq $null)
                {
                    $portname = "$Using:IPAddress - $Using:printername"
                    Add-PrinterPort -Name $portname -PrinterHostAddress $Using:IPAddress
                    Set-Printer -Name $Using:printername -Shared $false -ErrorAction Stop
                    Set-Printer -Name $Using:printername -DriverName $driver -Location $Using:location -Comment $Using:Comment -PortName $portname
                    Set-Printer -Name $Using:printername -Shared $true
                }
                if ($Using:newname -ne $null)
                {
                    Write-Host -ForegroundColor Yellow -BackgroundColor Black "Changing name. WARNING: Changing the name will break all current connections with the printer. They will need to reconnect to the printer using the new name"
                    Rename-Printer -Name $Using:printername -newname $Using:newname
                }
                else 
                {
                    Set-Printer -Name $Using:printername -Shared $false -ErrorAction Stop
                    Set-Printer -Name $Using:printername -DriverName $driver -Location $Using:location -Comment $Using:Comment
                    Set-Printer -Name $Using:printername -Shared $true
                }
            }
            else 
            {
                Write-Host "Installing new printer..."
                $portname = "$Using:IPAddress - $Using:printername"
                Add-PrinterPort -Name $portname -PrinterHostAddress $Using:IPAddress
                Add-Printer -Name $Using:printername -DriverName $driver -Shared -Location $Using:location -Comment $Using:Comment -ErrorAction Stop -PortName $portname
            }
            Write-Host "`n`rPrinter successfully updated on $env:COMPUTERNAME!" -ForegroundColor Green -BackgroundColor Black
        }
    }
    get-pssession | Remove-PSSession
}