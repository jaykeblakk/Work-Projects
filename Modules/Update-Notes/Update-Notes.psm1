##########################
# Update VM Notes Script
# Written by Coby Carter
# Date last updated: 1/21/2020
# Last Update: Set $description and $owner to null at the end of the script. 
# This allows for multiple servers to be updated with different descriptions. 
# This will still make the description/owner pass through if this is being run
# in the Server Setup script.
##########################

function Update-Notes()
{
    [CmdletBinding()]
    # The servers parameter is mandatory and is an array. It takes a list of servers separated by commas.
    Param(
    [Parameter (Mandatory=$true)]
    [string[]]$servers,

    [Parameter (Mandatory=$false)]
    [string]$owner,

    [Parameter (Mandatory=$false)]
    [string]$description,

    [Parameter (Mandatory=$false)]
    [string]$Ticket
    )
    # This checks to see if we are connected to vSphere already. If not, it connects us.
    $viserver = $global:DefaultVIServer
    if ($viserver -eq $null)
    {
        Connect-ViServer vcenterurl.example.com
    }
    foreach ($server in $servers)
    {
        $VMName = $server
        Write-Host "Configuring settings for $server..."
        if([string]::IsNullOrEmpty($Ticket))
        {
            $Ticket = Read-Host "Ticket #"
        }
        # If we passed in a description earlier, this will not prompt.
        if([string]::IsNullOrEmpty($description))
        {
            $description = Read-Host "Description"
        }
        
        if([string]::IsNullOrEmpty($owner))
        {
            $owner = Read-Host "Owner/Requester"
        }
        $Notes = "Ticket #: " + $Ticket + "`nDescription: " + $description
        $environment = Read-Host "Environment (Dev/Prod)"
        # From here on down is setting all of the variables that we prompted for.
        $VM = get-vm -Name $VMName
        Set-Annotation $VM -CustomAttribute "App Admin" -Value $owner
        Set-Annotation $VM -CustomAttribute "Env" -Value $environment
        Set-Annotation $VM -CustomAttribute "System Owner" -Value $Owner
        set-vm -VM $VM -Notes $Notes -confirm:$false
        $owner = $null
        $description = $null
    }
}