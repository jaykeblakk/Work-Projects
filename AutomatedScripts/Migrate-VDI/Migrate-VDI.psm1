function Migrate-VDI()
{
    Connect-VIServer horizonurl.example.com
    $creds = Get-Credential
    $machines = Import-Excel "C:\temp\vdi list.xlsx" | where datastore -notlike "*mxvdi*" | select machine 
    $jobs = foreach ($machine in $machines)
    {
        start-threadjob {
            Connect-hvserver horizonviewurl.example.com -Credential $Using:creds
            $machinename = $Using:machine
            $machinename = $machinename.Machine
            $vm = Get-HVMachine -MachineName $machinename
            if ($vm.base.basicstate -like "AVAILABLE")
            {
                $vdi = $machinename
                Write-Host -foregroundcolor Yellow -backgroundcolor Black "Stopping $vdi..."
                Stop-VM $vdi -Confirm:$false
                Write-Host -foregroundcolor Yellow -backgroundcolor Black "Pulling migration information..."
                $destination = get-vmhost | where name -like "*vdihost*" | sort-object freespacegb -descending | select -first 1
                $networkAdapter = get-networkadapter $vdi
                $destinationportgroup = Get-VDPortgroup -VDSwitch "DSwitch_VXLAN" -name "VXLAN-VDI"
                $destinationDatastore = get-datastore | where name -like "*vdihost*" | sort-object freespacegb -descending | select -first 1
                Write-Host -ForegroundColor Yellow -BackgroundColor Black "Beginning migration for $vdi..."
                Move-VM -VM $vdi -Destination $destination -NetworkAdapter $networkAdapter -PortGroup $destinationportgroup -Datastore $destinationDatastore -RunAsync
                Write-Host -ForegroundColor Green -BackgroundColor Black "Migration for $vdi has begun! Check the status in vcenter."
            }
            else 
            {
                continue
            }
        } -throttlelimit 5     
    }
    foreach ($job in $jobs){Receive-job $job -wait -autoremovejob}    
}