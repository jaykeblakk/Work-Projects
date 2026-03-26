<#
.SYNOPSIS
    Renames servers in both Active Directory and VMware environments.

.DESCRIPTION
    This script coordinates server renaming operations across multiple systems by updating computer 
    names in Active Directory, adjusting VM names in vcenter, and handling storage migrations to 
    maintain consistency. It manages the restart process and ensures proper datastore selection 
    based on the current environment.

.NOTES
    Author: Coby Carter
    Last Updated: 11/22/2024
    Change History:
    11/22/2024 - Initial script creation

.PARAMETER servers
    Array of server names to be renamed. Multiple servers can be specified separated by commas.

.EXAMPLE
    Rename-Servers -servers "OLDNAME01","OLDNAME02"

    Renames the specified servers, updates AD and vcenter configurations, and migrates the VMs 
    to appropriate datastores while maintaining system consistency.
#>
function Rename-Servers()
{
    [CmdletBinding()]
    # The servers parameter is mandatory and is an array. It takes a list of servers separated by commas.
    Param(
    [Parameter (Mandatory=$true)]
    [string[]]$servers
    )

    # Here we check to see if we are already connected to a vSphere server. If not, then I connect us to it.
    $viserver = $global:DefaultVIServer
    if ($viserver -eq $null)
    {
        Connect-ViServer vcenterurl.example.com
    }

    $creds = Get-Credential -Message "Please enter your DA credentials"

    foreach ($server in $servers)
    {
        $newname = Read-Host "Please enter the new name for $server"
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Renaming & restarting $server..."
        $ses = New-PSSession -ComputerName $server -Credential $creds
        Invoke-Command -Session $ses -ScriptBlock {
            Rename-Computer -NewName $Using:newname -Force -Restart -DomainCredential $Using:creds
        }
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Setting the new VM name in vcenter..."
        $vm = Get-VM -Name $server | select *
        $datastore = $vm.extensiondata.config.datastoreurl.name
        if ($datastore -eq "Example Datastore")
        {
            $newdatastore = "Example Datastore2"
        }
        elseif ($datastore -eq "Example Datastore2")
        {
            $newdatastore = "Example Datastore"
        }
        elseif ($datastore -like "*Example Datastore 2*")
        {
            $newdatastore = get-datastore | where name -like "*Example Datastore 2*" | sort-object FreeSpaceGB -Descending | select -first 1
            if ($newdatastore.name -eq $datastore)
            {
                $newdatastore = get-datastore | where name -like "*Example Datastore 2*" | sort-object FreeSpaceGB -Descending | select -skip 1 -first 1
            }
        }
        elseif ($datastore -like "*Example Datastore 3*")
        {
            $newdatastore = get-datastore | where name -like "Example Datastore 3*" | sort-object FreeSpaceGB -Descending | select -first 1
            if ($newdatastore.name -eq $datastore)
            {
                $newdatastore = get-datastore | where name -like "Example Datastore 3*" | sort-object FreeSpaceGB -Descending | select -skip 1 -first 1
            }
        }
        Set-VM -VM $server -Name $newname -Confirm:$false
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Migrating the server..."
        Move-VM -VM $newname -Datastore $newdatastore -Confirm:$false -RunAsync
        Write-Host -ForegroundColor Green -BackgroundColor Black "$server has been renamed to $newname successfully!"
    }
}