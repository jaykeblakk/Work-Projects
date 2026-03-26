<#
.SYNOPSIS
    Adds new servers to SolarWinds Orion monitoring platform with proper configurations.

.DESCRIPTION
    This script automates the process of adding servers to Orion monitoring by retrieving IP 
    information directly from vSphere, creating the node in Orion, and configuring custom 
    properties including contact information and ticket numbers.

.NOTES
    Author: Coby Carter
    Last Updated: 02/19/2021
    Change History:
    02/19/2021 - Changed IP retrieval method to pull directly from vSphere instead of using Test-Connection

.PARAMETER server
    Name of the server to be added to Orion monitoring.

.PARAMETER contact
    Name of the primary contact for the server.

.PARAMETER contactemail
    Email address of the primary contact.

.PARAMETER Ticket
    POB ticket number associated with the server addition.

.EXAMPLE
    Add-OrionServer -server "NEWSRV01" -contact "John Smith" -contactemail "john.smith@aruplab.com" -Ticket "POB12345"

    Adds NEWSRV01 to Orion monitoring with specified contact information and ticket number.
#>
function Add-OrionServer()
{
    [CmdletBinding()]

    Param(
    [Parameter (Mandatory=$true)]
    [string]$server,

    [Parameter (Mandatory=$true)]
    [string]$contact,

    [Parameter (Mandatory=$true)]
    [string]$contactemail,

    [Parameter (Mandatory=$true)]
    [string]$Ticket
    )
    $viserver = $global:DefaultVIServer
    if ($viserver -eq $null)
    {
        Write-Host -ForegroundColor Green -BackgroundColor Black "Connecting to vSphere..."
        Connect-ViServer vcenterurl.example.com
    }
    import-module SwisPowerShell
    Import-Module PowerOrion
    $swis = Connect-Swis -Hostname orionurl.example.com -Credential (get-credential -Message "Please log in to Orion.")
    $serverinfo = get-vm $server | select *
    $IP = $serverinfo.extensiondata.guest.ipaddress
    $credentialidnumber = Read-Host "Please enter the credential ID number"
    $engineidnumber = Read-Host "Please enter the engine ID number"
    Write-Host "Adding the new node to Orion..." -ForegroundColor Yellow -BackgroundColor Black
    $newnode = New-OrionNode -SwisConnection $swis -IPAddress $IP -CredentialID $credentialidnumber -objectsubtype WMI -EngineID $engineidnumber # The output of this command is an array of swis URI's
    Write-Host "Node Added!" -ForegroundColor Green -BackgroundColor Black
    $uri = $newnode[-1] # Selects the last object in the array
    $name = @{
        NodeName="$server";
    }
    Set-SwisObject $swis -uri $uri -Properties $name
    $uri += "/customproperties" # Append this to the end of the URI to access custom properties in Orion.
    $customproperties = @{
        Comments="Ticket #: $Ticket";
        ContactEmail="$Contactemail";
        ContactName="$contact";
        Environment="Environment";
        Node_Type="Server";
    }
    Set-SwisObject $swis -uri $uri -Properties $customproperties
    Write-Host "Node configured." -ForegroundColor Green -BackgroundColor Black
}