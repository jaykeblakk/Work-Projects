<#
.SYNOPSIS
    Configures network settings for VMs across different environments.

.DESCRIPTION
    This script manages VM network configuration by assigning IP addresses, configuring network 
    adapters, setting up DNS for development, certification, and production environments, and creating DNS host records in Infoblox.
    It handles networking, genetics sequencing networks, and ensures proper network 
    migration from development domains.

.NOTES
    Author: Coby Carter
    Last Updated: 7/22/2024
    Change History:

.PARAMETER server
    Name of the server to configure network settings.

.EXAMPLE
    Set-VMIP -server "NEWSRV01"

    Configures network settings for NEWSRV01 based on its host environment, including IP assignment, 
    network adapter setup, and DNS configuration/registration in Infoblox.
#>
function Set-VMIP()
{
    [CmdletBinding()]
    Param(

    [Parameter (Mandatory=$true)]
    [string]$server
    )
    #$type = $null
    $vmhost = Get-VM $server | select VMHost
    $vmhost = $vmhost.vmhost.name
    $creds = Get-Credential -Message "Please enter your DA credentials" -UserName "exampledomain\"
    if (($vmhost -like '*Example*') -or ($vmhost -like "*example2*") -or ($vmhost -like "*example3*"))
    {
        while (($certordev -ne 'c') -and ($certordev -ne 'd'))
        {
            $certordev = Read-Host "Will this server be Cert or Dev (c/d)"
            if ($certordev -eq 'd')
            {
                # Get the subnet that we want from IB, and then pull the next IP.
                $subnet = Get-IBObject -type network -Filters 'network=0.0.0.0/subnetnumber'
                $ip = $subnet | Invoke-IBFunction -name 'next_available_ip' -args @{num=1} | select -expand ips
                $gateway = "0.0.0.0"
                #invoke-vmscript -vm $server -Scripttext $registerdns -GuestCredential $creds # Removed registerdns
                $adapter = Get-NetworkAdapter -VM $server
                $session = New-PSSession -ComputerName $server -credential $creds
                Invoke-command -session $session -ScriptBlock {get-netadapter | rename-netadapter -newname 'Ethernet'}
                New-NetworkAdapter -VM $server -Confirm:$false -NetworkName "Example-Dev-NetworkName" -StartConnected:$true -type Vmxnet3 -WakeOnLan:$true
                Write-Host "New Adapter added! Waiting for the OS to recognize it..." -ForegroundColor Yellow -BackgroundColor Black
                Start-Sleep -seconds 15
                Invoke-command -session $session -scriptblock {$adaptername = Get-NetAdapter | where name -ne 'Ethernet' | select name
                $adaptername = $adaptername.name 
                New-NetIPAddress -IPAddress $Using:ip -InterfaceAlias $adaptername -DefaultGateway $Using:gateway -AddressFamily IPv4 -PrefixLength 20}
                Invoke-Command -session $session -Scriptblock {$adaptername = Get-NetAdapter | where name -ne 'Ethernet' | select name; 
                    $adaptername = $adaptername.name
                    Set-DnsClientServerAddress -InterfaceAlias $adaptername -serverAddresses 0.0.0.0}
                #Invoke-Command -session $session -scriptblock {ipconfig /registerdns} # Replaced with New-IBRecordHost
                try {
                    $newHostRecord = @{
                        name = $server + ".example.com" # Assuming $server is FQDN, adjust if needed
                        ipv4addrs = @(
                            @{
                                ipv4addr = $ip
                            }
                        )
                    }
                    # Create the host record
                    Write-Host "Creating Infoblox host record for $server with IP $ip..." -ForegroundColor Cyan
                    $newHost = New-IBObject -ObjectType "record:host" -IBObject $newHostRecord -ErrorAction Stop
                    Write-Host "Successfully created Infoblox host record." -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to create Infoblox host record for $server. Error: $_"
                    # Optionally, add more error handling or logging here
                }
                $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                $vm = get-vm $server
                $Adapter = Get-NetworkAdapter -VM $vm|?{$_.NetworkName -like "*example-dev-networkname*"}
                $devSpec = New-Object VMware.Vim.VirtualDeviceConfigSpec
                $devSpec.operation = "remove"
                $devSpec.device += $Adapter.ExtensionData
                $spec.deviceChange += $devSpec
                $VM.ExtensionData.ReconfigVM_Task($spec)
            }
            elseif ($certordev -eq 'c')
            {
                $subnet = Get-IBObject -type network -Filters 'network=0.0.0.0/subnetnumber'
                $ip = $subnet | Invoke-IBFunction -name 'next_available_ip' -args @{num=1} | select -expand ips
                $gateway = "0.0.0.0"
                #invoke-vmscript -vm $server -Scripttext $registerdns -GuestCredential $creds # Removed registerdns
                $adapter = Get-NetworkAdapter -VM $server
                $session = New-PSSession -ComputerName $server -credential $creds
                Invoke-command -session $session -ScriptBlock {get-netadapter | rename-netadapter -newname 'Ethernet'}
                New-NetworkAdapter -VM $server -Confirm:$false -NetworkName "Example-Cert-NetworkName" -StartConnected:$true -type Vmxnet3 -WakeOnLan:$true
                Write-Host "New Adapter added! Waiting for the OS to recognize it..." -ForegroundColor Yellow -BackgroundColor Black
                Start-Sleep -seconds 15
                Invoke-command -session $session -scriptblock {$adaptername = Get-NetAdapter | where name -ne 'Ethernet' | select name
                $adaptername = $adaptername.name 
                New-NetIPAddress -IPAddress $Using:ip -InterfaceAlias $adaptername -DefaultGateway $Using:gateway -AddressFamily IPv4 -PrefixLength 20}
                Invoke-Command -session $session -Scriptblock {$adaptername = Get-NetAdapter | where name -ne 'Ethernet' | select name; 
                    $adaptername = $adaptername.name
                    Set-DnsClientServerAddress -InterfaceAlias $adaptername -serverAddresses 0.0.0.0}
                #Invoke-Command -session $session -scriptblock {ipconfig /registerdns} # Replaced with New-IBRecordHost
                try {
                    $newHostRecord = @{
                        name = $server + ".example.com" # Assuming $server is FQDN, adjust if needed
                        ipv4addrs = @(
                            @{
                                ipv4addr = $ip
                            }
                        )
                    }
                    # Create the host record
                    Write-Host "Creating Infoblox host record for $server with IP $ip..." -ForegroundColor Cyan
                    $newHost = New-IBObject -ObjectType "record:host" -IBObject $newHostRecord -ErrorAction Stop
                    Write-Host "Successfully created Infoblox host record." -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to create Infoblox host record for $server. Error: $_"
                    # Optionally, add more error handling or logging here
                }
                $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                $vm = get-vm $server
                $Adapter = Get-NetworkAdapter -VM $vm|?{$_.NetworkName -like "*example-dev-networkname*"}
                $devSpec = New-Object VMware.Vim.VirtualDeviceConfigSpec
                $devSpec.operation = "remove"
                $devSpec.device += $Adapter.ExtensionData
                $spec.deviceChange += $devSpec
                $VM.ExtensionData.ReconfigVM_Task($spec)
            }
            else 
            {
                Write-Host "Invalid Entry." -ForegroundColor Red -BackgroundColor Black
            }
        }
    }
    elseif (($vmhost -like '*Example*') -or ($vmhost -like "*example2*") -or ($vmhost -like "*example3*"))
    {
        $subnet = Get-IBObject -type network -Filters 'network=0.0.0.0/subnetnumber'
        $ip = $subnet | Invoke-IBFunction -name 'next_available_ip' -args @{num=1} | select -expand ips
        $gateway = "0.0.0.0"
        #invoke-vmscript -vm $server -Scripttext $registerdns -GuestCredential $creds # Removed registerdns
        $adapter = Get-NetworkAdapter -VM $server
        $session = New-PSSession -ComputerName $server -credential $creds
        Invoke-command -session $session -ScriptBlock {get-netadapter | rename-netadapter -newname 'Ethernet'}
        New-NetworkAdapter -VM $server -Confirm:$false -NetworkName "Example-Prod-NetworkName" -StartConnected:$true -type Vmxnet3 -WakeOnLan:$true
        Write-Host "New Adapter added! Waiting for the OS to recognize it..." -ForegroundColor Yellow -BackgroundColor Black
        Start-Sleep -seconds 15
        Invoke-command -session $session -scriptblock {$adaptername = Get-NetAdapter | where name -ne 'Ethernet' | select name
        $adaptername = $adaptername.name 
        New-NetIPAddress -IPAddress $Using:ip -InterfaceAlias $adaptername -DefaultGateway $Using:gateway -AddressFamily IPv4 -PrefixLength 20}
        Invoke-Command -session $session -Scriptblock {$adaptername = Get-NetAdapter | where name -ne 'Ethernet' | select name; 
            $adaptername = $adaptername.name
            Set-DnsClientServerAddress -InterfaceAlias $adaptername -serverAddresses 0.0.0.0}
        #Invoke-Command -session $session -scriptblock {ipconfig /registerdns} # Replaced with New-IBRecordHost
        try {
            $newHostRecord = @{
                name = $server + ".example.com" # Assuming $server is FQDN, adjust if needed
                ipv4addrs = @(
                    @{
                        ipv4addr = $ip
                    }
                )
            }
            # Create the host record
            Write-Host "Creating Infoblox host record for $server with IP $ip..." -ForegroundColor Cyan
            $newHost = New-IBObject -ObjectType "record:host" -IBObject $newHostRecord -ErrorAction Stop
            Write-Host "Successfully created Infoblox host record." -ForegroundColor Green
        } catch {
            Write-Warning "Failed to create Infoblox host record for $server. Error: $_"
            # Optionally, add more error handling or logging here
        }
        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $vm = get-vm $server
        $Adapter = Get-NetworkAdapter -VM $vm|?{$_.NetworkName -like "*example-dev-networkname*"}
        $devSpec = New-Object VMware.Vim.VirtualDeviceConfigSpec
        $devSpec.operation = "remove"
        $devSpec.device += $Adapter.ExtensionData
        $spec.deviceChange += $devSpec
        $VM.ExtensionData.ReconfigVM_Task($spec)
    }
    Write-Host "IP Address assigned, network adapter configured, and DNS record created." -ForegroundColor Green -BackgroundColor Black
}
    #Invoke-VMScript -VM $server -ScriptText "ipconfig /registerdns" -GuestCredential $creds # Removed final registerdns
