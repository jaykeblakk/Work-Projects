####################
# This script automates the setup process for the Sales Images that are used with imaging. These images are on the Test Server
# Written by Coby Carter
####################

function Setup-ServiceImage
{
    # Copy adminsoftware to the computer
    robocopy /e /mt:32 "\\IPADDR\public\NewComputerSetupFiles\AdminSoftware" "C:\adminsoftware"

    # Install all other users on the computer
    Start-Process "C:\adminsoftware\Scripts\users\CreateAll.bat" -Wait

    # Run Ninite to install all normal programs
    Start-Process "C:\adminsoftware\All\Ninite 7Zip Chrome Firefox Foxit Reader Greenshot Installer.exe" -Wait

    # Copy PFWUtil folder to the hard drive
    robocopy /e /mt:32 "C:\adminsoftware\pfw\PFWUtil" "C:\PFWUtil"

    # Install .Net 3.5
    DISM /Online /Enable-Feature /FeatureName:NetFx3 /All

    # Install RC Apps
    Start-Process "C:\adminsoftware\all\RingCentral\Win\RCApp.msi" -Wait
    Start-Process "C:\adminsoftware\all\RingCentral\Win\RCPhone.msi" -Wait
    Start-Process "C:\adminsoftware\all\RingCentral\Win\RCMeetings.msi" -Wait
    Start-Process "C:\adminsoftware\all\RingCentral\Win\RCOutlook.msi" -Wait

    # Create Desktop shortcuts for PFW, Utiliprong, and IronHQ
    Copy-Item "C:\adminsoftware\all\shortcuts\ultipro.lnk" $env:USERPROFILE\Desktop
    Copy-Item "C:\adminsoftware\all\shortcuts\PFW Chrome.lnk" $env:USERPROFILE\Desktop
    Copy-Item "C:\adminsoftware\all\shortcuts\IronHQ.lnk" $env:USERPROFILE\Desktop

    # Install Office Starter + PP Viewer
    Read-Host "Please disable IPv6 on this machine. The installer for Office Starter 2010 will fail if it isn't disabled. Press Enter to proceed"
    & 'C:\adminsoftware\Office\Office Starter 2010\setupconsumerc2rolw.exe'
    & 'C:\adminsoftware\Office\Office Starter 2010\click2run2010-kb2598285-fullfile-x86-glb.exe'
    & 'C:\adminsoftware\Office\Office Starter 2010\PowerPointViewer.exe'

    # Install the Cisco VPN and add the necessary registry key to make it work
    C:\adminsoftware\VPN\VPN.bat
    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services" -Name 'CVirtA' -Force
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CVirtA" -Name "DisplayName" -Value "Cisco Systems VPN Adapter for 64-bit Windows" -Force
    Copy-Item "C:\adminsoftware\All\Shortcuts\VPN Client.lnk"

    # Install K-Pad
    & 'C:\adminsoftware\Service\Kubota\Kpad\1Kubota-PAD_V1.3_20160301_2.exe'

    # Install Diagmaster
    C:\adminsoftware\Service\Kubota\Diagmaster4.20\Kubota.bat

    # Install Perkins EST
    & 'C:\adminsoftware\Service\Wintest\1- EST\Software Wheeled Tractor Perkins EST2008B\CD\EST\EST-AGCO 2008B v1.0-E8 (Build 552).exe'

    # Install WinEEM4
    & 'C:\adminsoftware\Service\Wintest\2- EEM\WinEEM4s-1.19.1_full\setup.exe'

    # Install 2.20.XX AGCO and Challenger
    Expand-Archive 'C:\adminsoftware\Service\Wintest\3- 2.20.XX\Agco\V2.20.01_AGCO.zip' -Force -destinationpath "C:\adminsoftware\Service\Wintest\3- 2.20.XX\Agco\"
    Expand-Archive 'C:\adminsoftware\Service\Wintest\3- 2.20.XX\Challenger\V2.20.01_Challenger.zip' -Force -destinationpath "C:\adminsoftware\Service\Wintest\3- 2.20.XX\Challenger\"
    & 'C:\adminsoftware\Service\Wintest\3- 2.20.XX\Agco\V2.20.01 AGCO\Data\Disk1\setup.exe'
    & 'C:\adminsoftware\Service\Wintest\3- 2.20.XX\Challenger\V2.20.01 Challenger\Data\Disk1'

    Read-Host "Please run both programs as administrator and install the drivers before proceeding to update them. Press Enter once the driver installation has completed"

    # Run the updater to get both of them up to date without waiting on each installation
    & 'C:\adminsoftware\Service\Wintest\3- 2.20.XX\WintestUpdates\wintestwin10.bat'

    # Install Cat ET
    & 'C:\adminsoftware\Service\Wintest\4- CAT ET\Cat ET 2018A v1.0.exe'

    Write-Host "Please remember to restart the computer once all configuration has finished."
}