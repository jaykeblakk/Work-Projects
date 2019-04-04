####################
# This script automates the setup process for the Sales Images that are used with imaging. These images are on the Test Server
# Written by Coby Carter
####################

function Setup-SalesImage
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

    # Install Office 365
    C:\adminsoftware\Office\Office365\as-Install.bat

    # Install the Cisco VPN and add the necessary registry key to make it work
    C:\adminsoftware\VPN\VPN.bat
    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services" -Name 'CVirtA' -Force
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CVirtA" -Name "DisplayName" -Value "Cisco Systems VPN Adapter for 64-bit Windows" -Force
    Copy-Item "C:\adminsoftware\All\Shortcuts\VPN Client.lnk"




    Write-Host "Please remember to restart the computer once all configuration has finished."
}