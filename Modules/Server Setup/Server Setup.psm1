<#
.SYNOPSIS
    Performs comprehensive server configuration after initial deployment.

.DESCRIPTION
    This script handles post-deployment server configuration including CPU allocation, memory sizing, 
    disk configuration, and network setup. It manages domain joining, drive formatting, and system 
    settings across multiple servers while coordinating with vSphere for resource allocation and 
    Orion for monitoring setup.

.NOTES
    Author: Coby Carter
    Last Updated: 3/31/2022
    Change History:

.PARAMETER servers
    Array of server names to be configured. Multiple servers can be specified separated by commas.

.EXAMPLE
    Configure-Servers -servers "NEWSRV01"

    Configures a single server with CPU, memory, storage, and network settings based on interactive prompts.

.EXAMPLE
    Configure-Servers -servers "NEWSRV01","NEWSRV02","NEWSRV03"

    Configures multiple servers simultaneously, prompting for resource allocation and configuration options for each.
#>

function Configure-Servers()
{
    [CmdletBinding()]
    # The servers parameter is mandatory and is an array. It takes a list of servers separated by commas.
    Param(
    [Parameter (Mandatory=$true)]
    [string[]]$servers
    )
    connect-viserver -server vcenterurl.example.com
    <#foreach ($server in $servers)
    {
        get-vm $server | restart-vm
    }#>
    Write-host "Prompting for credentials...."
    $Creds = Get-Credential -Message "Please enter your DA Credentials for the server."
    $serverobjects = @()
    $cpu = $null
    $mem = $null
    $dsize = $null
    foreach ($server in $servers)
    {   
        $cpu = Read-Host "How many CPU's are requested for $server"
        $mem = Read-Host "How much memory is requested (in GB) for $server"
        $dsize = Read-Host "How big does the D drive need to be (in GB)"
        $serverhash = New-Object psobject -Property @{
            "Server Name" = $server
            "C Drive (in GB)" = $csize
            "D Drive (in GB)" = $dsize
        }
        $serverobjects += $serverhash
    }
    $choice = Read-Host "Will all, some, or none of the servers need to send emails? a/s/n"
    # Loop through all of the servers and write them out with a number.
    # Write out which numbers you want separated by commas.
    if ($choice -eq 's')
    {
        $counter = 0
        foreach ($server in $servers)
        {
            Write-Host "${counter}: $server"
            $counter++
        }
        $emailservers = Read-Host "Select the servers that need email access: "
        $emailservers = $emailservers.Replace(' ','')
        $emailservers = $emailservers.Split(',')
        $counter = 0
        foreach ($emailserver in $emailservers)
        {
            $emailservers[$counter] = $servers[$emailserver]
            $counter++
        }
    }
    Clear-Host
    Write-Host "`n`rPlease ensure the following settings are correct`n`r"
    Write-Host "Server list: "
    foreach ($serverobject in $serverobjects)
    {
        $serverobject | format-table -Property "Server Name", "C Drive (in GB)", "D Drive (in GB)"
    }
    if ($choice -eq 'a')
    {
        $emailservers = $servers
        Write-Host "`n`rAll servers will send emails."
    }
    elseif ($choice -eq 's')
    {
        Write-Host "`n`rThe following will be able to send email: "
        # Display all of the servers that were selected to send emails
        foreach ($emailserver in $emailservers)
        {
            $emailserver
        }    
    }
    else
    {
        Write-Host "`n`rNo servers will send emails."
    }
    $final = Read-Host "Is everything correct? y/n"
    <#
    Here is where the servers begin to get configured. We install .NET as a job,
    rather than at the front so that you can move on to configuring the next server
    without needing to wait for .NET to finish.

    After the server is configured, you adjust the VM notes and properties through
    the Update-Notes script.

    One more important note, the PSSessions that are created by Setup-Server are
    not removed by this command or Setup-Server. This is intentional, as it allows
    you to enter each session and check the .NET jobs for completion and errors.
    #>
    if ($final -eq 'y')
    {
        Clear-Host
        
        # Restart all VMs first
        Write-Host "Restarting all servers..." -ForegroundColor Yellow -BackgroundColor Black
        foreach ($server in $servers)
        {
            Write-Host "Rebooting $server..." -ForegroundColor Yellow
            Restart-VM -VM $server -Confirm:$false
        }
        
        # Wait for network connectivity on the first server only
        # By the time we finish configuring it, the others will be ready
        Write-Host "Waiting for network connectivity on $($servers[0])..." -ForegroundColor Yellow
        $firstServer = $servers[0]
        $networkReady = $false
        $maxRetries = 30  # Wait up to 5 minutes for first server (30 * 10 seconds)
        $retryCount = 0

        do {
            Start-Sleep -Seconds 10
            try {
                $pingResult = Test-NetConnection -ComputerName $firstServer -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                if ($pingResult) {
                    $networkReady = $true
                    Write-Host "$firstServer is now online and ready." -ForegroundColor Green
                }
            }
            catch {
                # Continue waiting
            }
            $retryCount++
            
            if ($retryCount -ge $maxRetries) {
                Write-Host "Warning: $firstServer may not be fully ready, but proceeding..." -ForegroundColor Red
                $networkReady = $true  # Force proceed after timeout
            }
        } while (-not $networkReady)
        
        Write-Host "Beginning configuration..." -ForegroundColor Green -BackgroundColor Black
        
        foreach ($server in $servers)
        {
            if ($emailservers -contains $server)
            {
                cls
                Write-Host "Adding CPU, Memory, and Hard Drive Space to $server" -ForegroundColor Yellow -BackgroundColor Black
                $viserver = $global:DefaultVIServer
                if ($viserver -eq $null)
                {
                    Connect-ViServer vcenterurl.example.com
                }
                Set-VM $server -NumCpu $cpu -MemoryGB $mem -confirm:$false
                Setup-Server -server $server -email $true -Credential $creds
                # We ask for the ticket, owner, and get information so that we can add it to the server info in vSphere
                # without needing to prompt for it again when adding it to Orion.
                $Ticket = Read-Host "Ticket #"
                $Owner = Read-Host "Owner/Requester ID"
                $contactemail = get-aduser $owner | select userprincipalname
                $contactemail = $contactemail.userprincipalname
                $firstname = get-aduser $owner | select givenname
                $lastname = get-aduser $owner | select surname
                $fullname = $firstname.givenname + ' ' + $lastname.surname
                $description = Read-Host "Please enter the description of the server"
                Update-Notes -servers $server -owner $fullname -description $description -Ticket $Ticket
                Update-Maintenance -servers $server -credential $Creds -description $description
                $environment = get-annotation -entity $server | select name, value | where name -eq "env"
                $environment = $environment.value
                if ($environment -eq "Prod")
                {
                    Add-OrionServer -server $server -contact $fullname -contactemail $contactemail -Ticket $Ticket
                }
                elseif (($environment -eq "Cert") -or ($environment -eq "Dev"))
                {
                    $serveradobject = get-adobject -Filter "Name -eq `'$server'"
                    $devOU = Get-ADOrganizationalUnit -Identity "OU=Servers,OU=Domain Computers,DC=companyname,DC=com"
                    $serveradobject | Move-ADObject -TargetPath $devOU -Credential $creds
                }
            }
            else 
            {
                cls
                Write-Host "Adding CPU, Memory, and Hard Drive Space..." -ForegroundColor Yellow -BackgroundColor Black
                $viserver = $global:DefaultVIServer
                if ($viserver -eq $null)
                {
                    Connect-ViServer vcenterurl.example.com
                }
                Set-VM $server -NumCpu $cpu -MemoryGB $mem -confirm:$false
                Write-Host "CPU and Memory configured." -ForegroundColor Yellow -BackgroundColor Black
                if ($null -eq $Creds) {
                    $Creds = Get-Credential -Message "Creds are null. Please re-enter your DA credentials."
                }
                Setup-Server -server $server -email $false -Credential $creds
                $Ticket = Read-Host "Ticket #"
                $owner = $null
                $contactemail = $null
                while ($contactemail -eq $null)
                {
                    $Owner = Read-Host "Owner/Requester ID"
                    $contactemail = get-aduser $owner | select userprincipalname
                    if ($contactemail -eq $null)
                    {
                        Write-Host "Please verify you typed the ID correctly. If you did, it's possible the user account in AD is not the user ID."
                    }
                }
                $contactemail = $contactemail.userprincipalname
                $firstname = get-aduser $owner | select givenname
                $lastname = get-aduser $owner | select surname
                $fullname = $firstname.givenname + ' ' + $lastname.surname
                $description = Read-Host "Please enter the description of the server"
                Update-Notes -servers $server -owner $fullname -description $description -Ticket $Ticket
                Update-Maintenance -servers $server -credential $Creds -description $description
                $environment = get-annotation -entity $server | select name, value | where name -eq "env"
                $environment = $environment.value
                if ($environment -eq "Prod")
                {
                    Add-OrionServer -server $server -contact $fullname -contactemail $contactemail -Ticket $Ticket
                }
                else 
                {
                    Write-Host "Placing dev server in the non-prod OU..."
                    Get-ADObject -Filter "DistinguishedName -like 'CN=$server,OU=Servers,OU=Domain Computers,DC=companyname,DC=com'" | Move-ADObject -TargetPath "OU=Servers,OU=Domain Computers,DC=companyname,DC=com" -Credential $creds
                }
            }
            $needsiis = $null 
            while (($needsiis -ne 'y') -and ($needsiis -ne 'n'))
            {
                $needsiis = Read-Host "Does $server need IIS installed? y/n"
                if ($needsiis -ne 'y' -and $needsiis -ne 'n')
                {
                    Write-Host "Invalid input" -BackgroundColor Black -ForegroundColor Red
                }
            }
            if ($needsiis -eq 'y')
            {
                Install-IIS $server
            }
            Write-Host "$server has been configured." -ForegroundColor Green -BackgroundColor Black
        }
    }
    Write-Host "All servers configured." -ForegroundColor Green -BackgroundColor Black
}

function Setup-Server()
{
    [CmdletBinding()]
    Param(

    [Parameter (Mandatory=$true)]
    [string]$server,

    [Parameter (Mandatory=$false)]
    [bool]$email,

    [Parameter (Mandatory=$true)]
    [pscredential]$Credential
    )

    $viserver = $global:DefaultVIServer
    if ($viserver -eq $null)
    {
        Connect-ViServer vcenterurl.example.com
    }
    # This is a failsafe to prevent accidental changes to production. All of the VM templates have had their notes adjusted to have
    # New VM at the beginning of their notes. If "New VM" is not found in the notes, then it is a server currently
    # running in the environment and it should not be changed.
    $failsafe = $false
    while ($failsafe -eq $false)
    {
        $vmnotes = Get-VM $server | select notes
        $vmnotes = $vmnotes.notes
        if ($vmnotes -notlike "New VM*")
        {
            Write-Host "The VM name that you have entered is for a server currently in place, not a new server."
            $server = Read-Host "Please enter the correct name of the server"
            $failsafe = $false
        }
        elseif ($vmnotes -like "New VM*")
        {
            $failsafe = $true
        }
    }
    $servervm = $server
    # Set the VM IP first so that the PSSession will connect properly.
    $ipchoice = Read-Host "Does $server need a new IP? y/n"
    if ($ipchoice -eq 'y')
    {
        Set-VMIP $server
    }
    Write-Host "Flushing DNS Cache for new server DNS information."
    Clear-DNSClientCache
    $server = $server[0..14] -join '' # Server names can only be 15 characters long.
    $tries = 0
    while ($tries -lt 5)
    {
        try
        {
            $session = New-PSSession -ComputerName $server -Credential $Credential -ErrorAction Stop
            $tries = 5
        }
        catch
        {
            Write-Host -ForegroundColor Red -BackgroundColor Black "Failed to connect to the server. If it's a prod server, please wait about 20 minutes and then press any key to try again"
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
            $tries++
        }
    }
    
    # Ask if this is a SQL server BEFORE adding the D drive
    $isSqlServer = Read-Host "Is $server a SQL server? (y/n)"

    # Ask for D drive size
    $ddrivesize = Read-Host "How big does the D drive need to be (in GB) for $server?"

    # Create and format D drive
    Write-Host "Adding D drive to the server..." -ForegroundColor Green -BackgroundColor Black
    New-HardDisk -vm $servervm -StorageFormat Thin -Persistence Persistent -CapacityGB $ddrivesize

    # Format the new D drive immediately
    Invoke-Command -Session $session -ScriptBlock {
        if ($Using:isSqlServer -eq 'y') {
            Write-Host "Formatting D drive for SQL Server with 64K block size..." -ForegroundColor Yellow
            Get-Disk | Where-Object {$_.PartitionStyle -eq 'RAW'} | Select-Object -First 1 |
            Initialize-Disk -PartitionStyle GPT -PassThru |
            New-Partition -UseMaximumSize -DriveLetter D |
            Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel "Data" -Confirm:$false
        } else {
            Write-Host "Formatting D drive with standard (4K) block size..." -ForegroundColor Yellow
            Get-Disk | Where-Object {$_.PartitionStyle -eq 'RAW'} | Select-Object -First 1 |
            Initialize-Disk -PartitionStyle GPT -PassThru |
            New-Partition -UseMaximumSize -DriveLetter D |
            Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
        }
    }
    
    $drives = 1
    $drivecount = Read-Host "How many extra drives will the server $server need?"
    # If we have no extra drives, we skip this entire part. If we have several, we start counting from 1 and go until we reach the count.
    if ($drivecount -ne 0)
    {
        while ($drives -le $drivecount)
        {
            $drivesize = $null
            while ($drivesize -notmatch '^[0-9]+$')
            {
                $drivesize = Read-Host "Enter the size (in GB) for extra drive $drives"
                if ($drivesize -notmatch '^[0-9]+$')
                {
                    Write-Host "Invalid input."
                }
            }
            Write-Host "Adding drive $drives to the server..." -ForegroundColor Green -BackgroundColor Black
            New-HardDisk -vm $servervm -StorageFormat Thin -Persistence Persistent -CapacityGB $drivesize
            Invoke-Command -Session $session -ScriptBlock {
                Write-Host "Checking for disks..."
                $disks = Get-Disk
                foreach ($disk in $disks)
                {
                    if ($disk.PartitionStyle -ne 'RAW')
                    {
                        continue
                    }
                    else
                    {
                        $letter = $null
                        while ($letter -notmatch '[a-zA-Z]' -or $letter.length -gt 1)
                        {
                            $letter = Read-Host "Please choose a drive letter for this drive"
                            if (($letter -notmatch '[a-zA-Z]') -or ($letter.Length -gt 1))
                            {
                                Write-Host "Invalid input."
                                continue
                            }
                            if ($letter -eq 'E' -or $letter -eq 'e')
                            {
                                $drv = get-WmiObject win32_volume -filter 'DriveLetter = "E:"'
                                if ($drv -ne $null)
                                {
                                    Write-Host "That drive letter is currently in use by the CD drive. Changing the CD drive..."
                                    $drv.DriveLetter = "Z:"
                                    $drv.Put() | out-null
                                }
                            }
                        }
                        $name = Read-Host "Enter the name of this drive"
                        if ($Using:drivesize -gt 1500)
                        {
                            Initialize-Disk -number $disk.number -PartitionStyle GPT -PassThru|
                            new-partition -UseMaximumSize -AssignDriveLetter |
                            Set-Partition -NewDriveLetter $letter
                            get-volume -DriveLetter $letter | 
                            format-volume -FileSystem NTFS -Confirm:$false |
                            Set-Volume -NewFileSystemLabel $name
                        }
                        else
                        {
                            Initialize-Disk -number $disk.number -PartitionStyle MBR -PassThru|
                            new-partition -UseMaximumSize -AssignDriveLetter |
                            Set-Partition -NewDriveLetter $letter
                            get-volume -DriveLetter $letter | 
                            format-volume -FileSystem NTFS -Confirm:$false |
                            Set-Volume -NewFileSystemLabel $name  
                        }
                    }
                }
            }
            $drives++
        }
    }
    # Install all of .NET Framework
    Write-Host "`nInstalling .NET" -ForegroundColor Yellow -BackgroundColor Black
    Invoke-Command -ComputerName $server -ScriptBlock {Install-WindowsFeature "Net-Framework-Features" -IncludeAllSubFeature} -AsJob -Credential $Credential
    Invoke-Command -ComputerName $server -ScriptBlock {Install-WindowsFeature "Net-Framework-45-Features" -IncludeAllSubFeature} -AsJob -Credential $Credential
    # Check if the server was correctly added to the domain and is named properly
    Invoke-Command -ComputerName $server -ScriptBlock{
        $name = [System.Net.Dns]::GetHostByName(($env:computerName))
        $name.HostName
        $verifyname = Read-Host "Is the above name correct? y/n"
        # If it's not set properly, rename it and add it to the domain
        if ($verifyname -eq 'n')
        {
            $newname = Read-Host "Please enter the computer's correct name"
            
            Rename-Computer -ComputerName $newname -DomainCredential $Credential -Force
            
        }
    } -Credential $Credential
}