####################
# This script automates the setup process for the Parts Images that are used with imaging. These images are on the Test Server
# Written by Coby Carter
####################

function Setup-PartsImage
{
    # Copy adminsoftware to the computer
    robocopy /e /mt:32 "\\IPADDR\public\NewComputerSetupFiles\AdminSoftware" "C:\adminsoftware"

    # Copy Epsilon Books
    Start-Process "C:\adminsoftware\Scripts\epsilon.bat"

    # Install all other users on the computer
    Start-Process "C:\adminsoftware\Scripts\users\CreateAll.bat" -Wait

    # Run Ninite to install all normal programs
    Start-Process "C:\adminsoftware\All\Ninite 7Zip Chrome Firefox Foxit Reader Greenshot Installer.exe" -Wait

    # Copy PFWUtil folder to the hard drive
    robocopy /e /mt:32 "C:\adminsoftware\pfw\PFWUtil" "C:\PFWUtil"

    # Install CDK Heavy Equipment Uploader and .Net 3.5
    DISM /Online /Enable-Feature /FeatureName:NetFx3 /All
    Start-Process "C:\adminsoftware\parts\cdk part uploader\Agco Installer.msi" -Wait

    # Install Epsilon
    Start-Process "C:\adminsoftware\EpsilonInstaller\Epsilon 2.1.80\setup.exe" -Wait

    # Install RC Apps
    Start-Process "C:\adminsoftware\all\RingCentral\Win\RCApp.msi" -Wait
    Start-Process "C:\adminsoftware\all\RingCentral\Win\RCPhone.msi" -Wait
    Start-Process "C:\adminsoftware\all\RingCentral\Win\RCMeetings.msi" -Wait
    Start-Process "C:\adminsoftware\all\RingCentral\Win\RCOutlook.msi" -Wait

    # Create Desktop shortcuts for PFW and Utiliprong
    Copy-Item "C:\adminsoftware\all\shortcuts\ultipro.lnk" $env:USERPROFILE\Desktop
    Copy-Item "C:\adminsoftware\all\shortcuts\PFW Chrome.lnk" $env:USERPROFILE\Desktop

    # Install K-Pad
    & 'C:\adminsoftware\Service\Kubota\Kpad\1Kubota-PAD_V1.3_20160301_2.exe'

    # Install IBM i Access for i Navigator. Renames a registry key so that it will install without a restart, then names it back after the install completes.
    $regpath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $OldName = "PendingFileRenameOperations"
    $NewName = "###PendingFileRenameOperations"
    Rename-ItemProperty -Path $regpath -Name $OldName -NewName $NewName -Force
    Start-Process "C:\pfwutil\ca\v7r1\windows\cwblaunch.exe" -Wait
    Rename-ItemProperty -Path $regpath -Name $NewName -NewName $OldName
    Write-Host "Please remember to restart the computer once all configuration has finished."
}