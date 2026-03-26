<#
.SYNOPSIS
    Prepares servers for decommissioning by disconnecting network adapters and moving to designated storage.

.DESCRIPTION
    This script automates the server decommissioning process by disconnecting network connectivity, 
    updating VM notes with decommission dates and ticket numbers, moving VMs to the decommissioned 
    folder, and handling storage migration.

.NOTES
    Author: Coby Carter
    Last Updated: 4/12/2023

.PARAMETER vms
    Array of VM names to be decommissioned. Multiple VMs can be specified separated by commas.

.EXAMPLE
    Decommission-Server -vms "SERVER01","SERVER02"

    Disconnects network adapters, updates notes with decommission information, and moves the specified 
    servers to the decommissioned location with appropriate storage placement.
#>
function Decommission-Server()
{
    cls
    $viserver = $global:DefaultVIServer
    if ($viserver -eq $null)
    {
        Write-Host -ForegroundColor Green -BackgroundColor Black "Connecting to vSphere..."
        Connect-ViServer vcenterurl.example.com
    }
    $vms = Read-Host "VM(s) to be decommissioned"
    $vms = $vms.replace(' ','')
    $vms = $vms.split(',')
    foreach ($vm in $vms)
    {
        try
        {
            $nic = Get-NetworkAdapter -VM $vm
            Set-networkadapter -NetworkAdapter $nic -Connected:$false -confirm:$false
        }
        catch
        {
            Write-Host "The network adapter for this machine has already been disconnected." -ForegroundColor Yellow -BackgroundColor Black
        }
        $resourcepool = Get-ResourcePool DecommissionedVMs
        $decomfolder = Get-Folder DecommissionedVMs
        $newdatastore = get-datastore | where {($_.name -like "*Example Datastore 1*") -and ($_.name -notlike "*Example Datastore 2*")} | sort-object FreeSpaceGB -Descending | select -first 1
        $notes = get-vm $vm | select notes
        $time = Read-Host "`r`nWill $vm be kept for 30 or 90 days?"
        if ($time -eq 30)
        {
            $ddate = (get-date).addmonths(1)
        }
        else 
        {
            $ddate = (get-date).addmonths(3)    
        }
        $ddate = get-date $ddate -Format MM/dd/yyyy
        $notes = get-vm $vm | select notes
        $notes = $notes.notes
        $notes += "`r`nDecommission Date: $ddate"
        set-vm $vm -notes $notes -confirm:$false
        Move-VM -VM $vm -InventoryLocation $decomfolder
        Write-Host "$vm has been moved to the decommissioned folder:" -ForegroundColor Green -BackgroundColor Black
        $vmobject = Get-VM $vm | select Name, Folder
        $vmname = $vmobject.Name
        $vmname = $vmname.toLower()
        $filter = ('canonical=' + $vmname + '.example.com')
        $CNAMEEntry = Get-IBObject 'record:cname' -Filters $filter -ReturnAllFields
        if ($CNAMEEntry -ne $null)
        {
            Write-Host "This machine has a CNAME record (alias). Please notify the ticket requester that the CNAME needs to be checked."
        }
        Move-VM -VM $vm -datastore $newdatastore -Destination $resourcepool -Confirm:$false -RunAsync  
    }
}