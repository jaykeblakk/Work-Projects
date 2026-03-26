function Change-AdapterProfile()
{
    [CmdletBinding()]

    Param(
    [Parameter (Mandatory=$true)]
    [string]$server
    )
    $creds = Get-Credential
    Write-Host "Enabling and Disabling the network adapter to set it to a domain network profile..."
    Invoke-Command -ComputerName $server -Credential $creds -ScriptBlock {$NetAdapter = Get-WMIObject Win32_NetworkAdapter -filter "Name='vmxnet3 ethernet adapter'"
    $NetAdapter.Disable()
    $NetAdapter.Enable()}
}