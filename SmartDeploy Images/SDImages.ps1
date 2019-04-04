###################################################################
# This script builds images for SmartDeploy. These images are always named the same, but have specific details about them that are changed throughout the script. These details are few, and everything else is created # the same way.
###################################################################

# READ BELOW BEFORE SCRIPT EXECUTION

###################################################################
# For this script to work, please install Windows Assessment and Deployment Kit, found here: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
# Should this link break, the installer is found on the NAS under Public\Tools\ADK.
# Once the Windows Assessment and Deployment Kit is installed, please download and run the Windows Media Creation Tool, found here: https://www.microsoft.com/en-us/software-download/windows10
##################################################################

function Rebuild-Images
{
	# Unpack the files in the iso, copy the Unattend.xml file, and then re-build the iso with the xml file in it to allow for unattended installation.
	Set-Alias 7z "C:\Program Files\7-Zip\7z.exe"
	# 7 Zip allows you to extract the files from an iso. E extracts, -y accepts any prompts as yes, -aoa allows for overwriting of any files in the directory, and -o is the output directory
	7z e -y -aoa "\\IPADDR\Public\SDImageResources\Windows10.iso" -o"\\IPADDR\Public\SDImageResources\Unattended_Installation"
	Copy-Item -Path "\\IPADDR\Public\SDImageResources\autounattend.xml" -Destination "\\IPADDR\Public\SDImageResources\Unattended_Installation"
	New-Item C:\ISO -ItemType "Directory"
	cd "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg"
	New-PSDrive -Name 'X' -PSProvider "Filesystem" -Root "\\IPADDR\Public"

	# This command comes from here: https://win10.guru/windows-10-unattended-install-media-part-5-sysprep-capture-image/
	.\oscdimg.exe -m -o -u2 -udfver102 -bootdata:2#p0,e,bX:\SDImageResources\Unattended_Installation\boot\etfsboot.com#pEF,e,bX:\SDImageResources\Unattended_Installation\efi\microsoft\boot\efisys_noprompt.bin X:\SDImageResources\Unattended_Installation C:\ISO\Windows10.iso

	# Copy the new ISO file to the test server to mount to the images for auto-installation
	Remove-Item -Path "C:\ISO\Windows10.iso" -Force
	Copy-Item -Path "C:\ISO\Windows10.iso" -Destination "\\SERVER\e$\windows10.iso"

	# Connect to and run a scriptblock on the test server.
	Invoke-Command -ComputerName ashyperv-test -scriptblock {
		$VMs = "Parts Image", "Sales Image", "Service Image"
		foreach ($VM in $VMs)
		{
			# The following part of the script checks to make sure that the VM is in the "Stopped" state before doing anything else. We don't want to delete a running VM!
			Write-Host "Checking for the $VM state...`n"
			try
			{
				$vmdetails = Get-VM -Name $VM
			}
			catch
			{
				# This try catch just makes the error more clear. Usually you don't get this error because all of the images are already there.
				$FailedMessage = $_.Exception.Message
				if ($FailedMessage -like 'Hyper-V was unable to find a virtual machine with name')
				{
					Write-Host "The $VM doesn't exist in Hyper-V. It was either already deleted manually or corrupted." -ForegroundColor Yellow -BackgroundColor Black
				}
			}
			if ($vmdetails.state -eq 'Running')
			{
				Write-Host "The $VM VM is running currently. Shutting down the VM...`n"
				Stop-VM -Name $VM -TurnOff -Force -Verbose
			}
			else
			{
				Write-Host "The $VM VM is not currently running.`n"
			}
			# Set the Drive location and the virtual drive size of each image. The Parts Image is on the E drive, the Sales on the F drive, and the Service on the G drive. Feel free to change or adjust these as you'd like, but always keep each image on a different drive for maximum output from the images.
			if ($VM -eq "Parts Image")
			{
				$drive = "E:\"
				$size = 500GB
			}
			elseif ($VM -eq "Sales Image")
			{
				$drive = "F:\"
				$size = 250GB
			}
			else
			{
				$drive = "G:\"
				$size = 500GB
			}
			# This section deletes everything that the VM's contain so that they are fresh. Then it configures the new VM's to have the same specs as the previous ones, mounts the windows ISO, and then starts the VM, booting into the Installation environment.
			Write-Host "Removing the $VM VM from Hyper-V...`n"
			Remove-VM -Name $VM -Force -verbose

			Write-Host "Deleting all files related to the $VM VM...`n"
			Remove-Item -Path "$drive$VM" -Recurse -Force

			Write-Host "Creating the new $VM VM...`n"
			New-VM -Name $VM -Path "$drive" -MemoryStartupBytes 16GB -NewVHDPath "$drive$VM\Virtual Hard Disks\$VM.vhdx" -Generation 2 -Force -NewVHDSizeBytes $size -SwitchName "External Network Switch"

			Write-Host "Upping Processor Count to 8...`n"
			Set-VM  -Name $VM -ProcessorCount 8
			
			Write-Host "Adding the SCSI Controller...`n"
			Add-VMScsiController -VMName $VM

			Write-Host "Mounting the ISO...`n"
			Add-VMDvdDrive -VMName $VM -ControllerNumber 1 -ControllerLocation 0 -path "E:\windows10.iso"

			$DVDDrive = Get-VMDvdDrive -VMName $VM
			$VHD = Get-VMHardDiskDrive -VMName $VM
			$Devices = $DVDDrive, $VHD
			Write-Host "Setting the proper boot order...`n"
			Set-VMFirmware -VMName $VM -BootOrder $Devices
			
			Write-Host "Starting the $VM VM...`n"
			Get-VM -Name $VM | Start-VM
		}
	}
}
