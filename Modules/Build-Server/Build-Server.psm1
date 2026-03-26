<#
.SYNOPSIS
    Creates new Windows servers in VMware environment with proper configurations.

.DESCRIPTION
    This script automates the server build process by creating VMs from templates, 
    placing them in the correct clusters and datastores, and configuring AD objects. 
    It handles multiple server builds simultaneously and supports various Windows 
    Server versions (2012 R2, 2016, 2019, 2022).

.NOTES
    Author: Coby Carter
    Last Updated: 11/15/2024

.PARAMETER servers
    Array of server names to be created. Multiple servers can be specified separated by commas.

.EXAMPLE
    Build-Servers -servers "NEWSRV01"

    Creates a new server named NEWSRV01 using the interactive prompts for cluster selection, 
    folder location, and Windows version.

.EXAMPLE
    Build-Servers -servers "NEWSRV01","NEWSRV02","NEWSRV03"

    Creates three new servers simultaneously, prompting for configuration options for each server.
#>

function Build-Servers()
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
    $vmnames = get-vm | select Name
    $vmnames = $vmnames.name
    foreach ($server in $servers)
    {
        if ($vmnames -contains $server)
        {
            Write-Host "The server $server already exists."
            $server = Read-Host "Please enter the correct name for the server"
        }
        $datastore
        $choice = 4
        # Here we prompt for which cluster the server will be on. If it doesn't match, they'll be stuck until they put in one of those numbers.
        while($choice -ge 4)
        {
            Write-Host "`n`r"
            Write-Host "0: Example Cluster Name 1"
            Write-Host "1: Example Cluster Name 2"
            Write-Host "2: Example Cluster Name 3"
            Write-Host "3: Example Cluster Name 4"
            [uint16]$choice = Read-Host "`n`rChoose what cluster $server will be on"
            if ($choice -eq 0)
            {
                $cluster = get-cluster | where name -like "Example Cluster Name 1"
                $datastore = get-datastorecluster "Example Datastore Cluster Name 1" | get-datastore | Sort-Object FreeSpaceGB -Descending | select -First 1
            }
            elseif ($choice -eq 1)
            {
                $cluster = get-cluster | where name -like "*Example Cluster Name 2*"
                $datastore = get-datastorecluster "Example Datastore Cluster Name 2" | get-datastore | Sort-Object FreeSpaceGB -Descending | select -First 1
            }
            elseif ($choice -eq 2)
            {
                $cluster = get-cluster | where name -like "*Example Cluster Name 3*"
                $datastore = get-datastorecluster "Example Datastore Cluster Name 3" | get-datastore | Sort-Object FreeSpaceGB -Descending | select -First 1
            }
            elseif ($choice -eq 3)
            {
                $cluster = get-cluster | where name -like "*Example Cluster Name 4*"
                $datastore = get-datastorecluster | where name -like "*Example Datastore Cluster Name 4*" | get-datastore | Sort-Object FreeSpaceGB -Descending | select -First 1
            }
            else
            {
                Write-Host ""
                Write-Host "Invalid entry." -BackgroundColor Black -ForegroundColor Red
            }
        }
        # This has to be case sensitive because it will only accept the name of the folder the VM is in. The vSphere folder structure isn't visible.
        $location = Read-Host "What folder will this VM be in? CASE SENSITIVE"
        $serverchoice = 0
        # Loop until a valid server choice is made
        while(($serverchoice -ne '1') -and ($serverchoice -ne '2') -and ($serverchoice -ne '3'))
        {
            $serverchoice = Read-Host "Will this be Server 2016 (1), 2019 (2), or 2022 (3)?"
            if ($serverchoice -eq '1')
            {
                $template = Get-Template -Name "Windows Server 2016 Template Example"
                $customization = Get-OSCustomizationSpec -Name "Windows Server 2016 Customization Spec Example" 
            }
            elseif ($serverchoice -eq '2')
            {
                $template = Get-Template -Name "Windows Server 2019 Template Example"
                $customization = Get-OSCustomizationSpec -Name "Windows Server 2019 Customization Spec Example" 
            }
            elseif ($serverchoice -eq '3')
            {
                $template = Get-Template -Name "Windows Server 2022 Template Example"
                $customization = Get-OSCustomizationSpec -Name "Windows Server 2022 Customization Spec Example" 
            }
            else 
            {
                Write-Host "Invalid server choice. Please enter 1, 2, or 3." -ForegroundColor Red
            }
        }
        # We create the VM here
        New-VM -Name $server -ResourcePool $cluster -Template $template -OSCustomizationSpec $customization -Location $location -DiskStorageFormat Thin -RunAsync -Datastore $datastore
        Start-Job -Name "Start $server" -ScriptBlock {
            Connect-ViServer vcenterurl.example.com
            while ($vm -eq $null)
            {
                $vm = get-vm $Using:server -ErrorAction SilentlyContinue
            }
            Start-VM $Using:server
        }
        $adobject = $null
        Start-Job -Name "Move Server AD Object" -ScriptBlock {
            Write-Host -foregroundcolor yellow -backgroundcolor Black "Checking for AD Object..."
            while ($adobject -eq $null)
            {
                $adobject = Get-ADComputer -Identity $Using:server -credential $Using:creds -ErrorAction SilentlyContinue
                if ($adobject -ne $null)
                {
                    Write-Host -ForegroundColor Green -BackgroundColor Black "Server AD Object found! Moving to correct OU..."
                    get-adcomputer -identity $using:server | Move-ADObject -TargetPath "OU=Servers,OU=Domain Computers,DC=company,DC=com" -Credential $Using:creds -Verbose
                    Write-Host -ForegroundColor Green -BackgroundColor Black "Server moved! Restarting to get correct GPO's..."
                }
            }
        }
    }
}