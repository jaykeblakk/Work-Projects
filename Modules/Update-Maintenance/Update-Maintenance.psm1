##########################
# Update Server Maintenance Script
# Written by Coby Carter
# Date last updated: 2/11/2021
# Last Update: Catch the error for not finding
# a server maintenance window. Also removed
# a window that was nonexistent.
##########################

function Update-Maintenance()
{
    [CmdletBinding()]

    Param(
    [Parameter (Mandatory=$true)]
    [string[]]$servers,

    [Parameter (Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter (Mandatory=$false)]
    [string]$description
    )
    if($Credential -eq $null)
    {
        $creds = Get-Credential
    }
    else
    {
        $creds = $Credential
    }
    foreach  ($server in $servers)
    {
        $identity = Get-ADComputer $server -Credential $creds
        $choice = Read-Host "Do you need to update the description for ${server} in AD? y/n"
        # If the description was already passed in, it will add it. Otherwise, it prompts for the description.
        if ($choice -eq 'y')
        {
            if ([string]::IsNullOrEmpty($description))
            {
                $description = Read-Host "Enter the description"
            }
            Set-ADComputer -Identity $identity -Description $description -Credential $creds
        }
        $description = $null
        $computergroups = Get-ADComputer $server -Properties memberof | select memberof
        $groups = $computergroups.memberof
        foreach($group in $groups)
        {
            if ($group -like "*Example Server AD Group*")
            {
                $servergroup = $group
            }
        }
        <#
        Here it will give an error if the server is not in a server maintenance group already. We catch the error
        and let the user know that it's not currently in a maintenance window.
        #>
        try
        {
            Get-ADGroup -Identity $servergroup | Remove-ADGroupMember -Members $identity -Credential $creds
        }
        catch
        {
            Write-Host "Server does not currently have a maintenance window." -BackgroundColor Black -ForegroundColor Yellow
        }
        # From here on down is all GUI creation. These first variables are all actions taken
        # after clicking the buttons. After that is just the creation of the buttons and window
        $MaintenanceWindow1Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 1" -Members $identity; $Form.close()}
        $MaintenanceWindow2Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 2" -Members $identity; $Form.close()}
        $MaintenanceWindow3Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 3" -Members $identity; $Form.close()}
        $MaintenanceWindow4Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 4" -Members $identity; $Form.close()}
        $MaintenanceWindow5Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 5" -Members $identity; $Form.close()}
        $MaintenanceWindow6Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 6" -Members $identity; $Form.close()}
        $MaintenanceWindow7Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 7" -Members $identity; $Form.close()}
        $MaintenanceWindow8Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 8" -Members $identity; $Form.close()}
        $MaintenanceWindow9Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 9" -Members $identity; $Form.close()}
        $MaintenanceWindow10Click = {Add-ADGroupMember -Credential $creds -Identity "Example Maintenance Window 10" -Members $identity; $Form.close()}

        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Application]::EnableVisualStyles()

        $Form                            = New-Object system.Windows.Forms.Form
        $Form.ClientSize                 = '569,627'
        $Form.text                       = "Form"
        $Form.TopMost                    = $false

        $Title                           = New-Object system.Windows.Forms.Label
        $Title.text                      = "Please select the correct maintenance window for $server"
        $Title.AutoSize                  = $true
        $Title.width                     = 50
        $Title.height                    = 15
        $Title.location                  = New-Object System.Drawing.Point(77,23)
        $Title.Font                      = 'Microsoft Sans Serif,10'

        $ExampleMaintenanceWindow1Label                     = New-Object system.Windows.Forms.Label
        $ExampleMaintenanceWindow1Label.text                = "Example Maintenance Window Day 1"
        $ExampleMaintenanceWindow1Label.AutoSize            = $true
        $ExampleMaintenanceWindow1Label.width               = 25
        $ExampleMaintenanceWindow1Label.height              = 10
        $ExampleMaintenanceWindow1Label.location            = New-Object System.Drawing.Point(91,50)
        $ExampleMaintenanceWindow1Label.Font                = 'Microsoft Sans Serif,10'

        $ExampleMaintenanceWindow2Label                  = New-Object system.Windows.Forms.Label
        $ExampleMaintenanceWindow2Label.text             = "Example Maintenance Window Day 2"
        $ExampleMaintenanceWindow2Label.AutoSize         = $true
        $ExampleMaintenanceWindow2Label.width            = 25
        $ExampleMaintenanceWindow2Label.height           = 10
        $ExampleMaintenanceWindow2Label.location         = New-Object System.Drawing.Point(90,355)
        $ExampleMaintenanceWindow2Label.Font             = 'Microsoft Sans Serif,10'

        $ExampleMaintenanceWindow3Label                 = New-Object system.Windows.Forms.Label
        $ExampleMaintenanceWindow3Label.text            = "Example Maintenance Window Day 3"
        $ExampleMaintenanceWindow3Label.AutoSize        = $true
        $ExampleMaintenanceWindow3Label.width           = 25
        $ExampleMaintenanceWindow3Label.height          = 10
        $ExampleMaintenanceWindow3Label.location        = New-Object System.Drawing.Point(79,260)
        $ExampleMaintenanceWindow3Label.Font            = 'Microsoft Sans Serif,10'

        $ExampleMaintenanceWindow4Label                    = New-Object system.Windows.Forms.Label
        $ExampleMaintenanceWindow4Label.text               = "Example Maintenance Window Day 4"
        $ExampleMaintenanceWindow4Label.AutoSize           = $true
        $ExampleMaintenanceWindow4Label.width              = 25
        $ExampleMaintenanceWindow4Label.height             = 10
        $ExampleMaintenanceWindow4Label.location           = New-Object System.Drawing.Point(360,50)
        $ExampleMaintenanceWindow4Label.Font               = 'Microsoft Sans Serif,10'

        $ExampleMaintenanceWindow5Label                    = New-Object system.Windows.Forms.Label
        $ExampleMaintenanceWindow5Label.text               = "Example Maintenance Window Day 5"
        $ExampleMaintenanceWindow5Label.AutoSize           = $true
        $ExampleMaintenanceWindow5Label.width              = 25
        $ExampleMaintenanceWindow5Label.height             = 10
        $ExampleMaintenanceWindow5Label.location           = New-Object System.Drawing.Point(98,420)
        $ExampleMaintenanceWindow5Label.Font               = 'Microsoft Sans Serif,10'

        $ExampleMaintenanceWindow1                    = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow1.text               = "Example Maintenance Window 1"
        $ExampleMaintenanceWindow1.width              = 172
        $ExampleMaintenanceWindow1.height             = 31
        $ExampleMaintenanceWindow1.location           = New-Object System.Drawing.Point(35,70)
        $ExampleMaintenanceWindow1.Font               = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow1.add_Click($ExampleMaintenanceWindow1Click)

        $ExampleMaintenanceWindow2                  = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow2.text             = "Example Maintenance Window 2"
        $ExampleMaintenanceWindow2.width            = 174
        $ExampleMaintenanceWindow2.height           = 30
        $ExampleMaintenanceWindow2.location         = New-Object System.Drawing.Point(37,375)
        $ExampleMaintenanceWindow2.Font             = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow2.add_Click($ExampleMaintenanceWindow2Click)

        $ExampleMaintenanceWindow3                          = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow3.text                     = "Example Maintenance Window 3"
        $ExampleMaintenanceWindow3.width                    = 178
        $ExampleMaintenanceWindow3.height                   = 30
        $ExampleMaintenanceWindow3.location                 = New-Object System.Drawing.Point(35,440)
        $ExampleMaintenanceWindow3.Font                     = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow3.add_Click($ExampleMaintenanceWindow3Click)

        $ExampleMaintenanceWindow4                   = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow4.text              = "Example Maintenance Window 4"
        $ExampleMaintenanceWindow4.width             = 178
        $ExampleMaintenanceWindow4.height            = 30
        $ExampleMaintenanceWindow4.location          = New-Object System.Drawing.Point(302,70)
        $ExampleMaintenanceWindow4.Font              = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow4.add_Click($ExampleMaintenanceWindow4Click)

        $ExampleMaintenanceWindow5                   = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow5.text              = "Example Maintenance Window 5"
        $ExampleMaintenanceWindow5.width             = 178
        $ExampleMaintenanceWindow5.height            = 30
        $ExampleMaintenanceWindow5.location          = New-Object System.Drawing.Point(302,105)
        $ExampleMaintenanceWindow5.Font              = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow5.add_Click($ExampleMaintenanceWindow5Click)

        $ExampleMaintenanceWindow6                    = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow6.text               = "Example Maintenance Window 6"
        $ExampleMaintenanceWindow6.width              = 178
        $ExampleMaintenanceWindow6.height             = 30
        $ExampleMaintenanceWindow6.location           = New-Object System.Drawing.Point(302,140)
        $ExampleMaintenanceWindow6.Font               = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow6.add_Click($ExampleMaintenanceWindow6Click)

        $ExampleMaintenanceWindow7                 = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow7.text            = "Example Maintenance Window 7"
        $ExampleMaintenanceWindow7.width           = 200
        $ExampleMaintenanceWindow7.height          = 30
        $ExampleMaintenanceWindow7.location        = New-Object System.Drawing.Point(34,280)
        $ExampleMaintenanceWindow7.Font            = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow7.add_Click($ExampleMaintenanceWindow7Click)

        $ExampleMaintenanceWindow8                 = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow8.text            = "Example Maintenance Window 8"
        $ExampleMaintenanceWindow8.width           = 215
        $ExampleMaintenanceWindow8.height          = 30
        $ExampleMaintenanceWindow8.location        = New-Object System.Drawing.Point(15,105)
        $ExampleMaintenanceWindow8.Font            = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow8.add_Click($ExampleMaintenanceWindow8Click)

        $ExampleMaintenanceWindow9                   = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow9.text              = "Example Maintenance Window 9"
        $ExampleMaintenanceWindow9.width             = 200
        $ExampleMaintenanceWindow9.height            = 30
        $ExampleMaintenanceWindow9.location          = New-Object System.Drawing.Point(290,175)
        $ExampleMaintenanceWindow9.Font              = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow9.add_Click($ExampleMaintenanceWindow9Click)

        $ExampleMaintenanceWindow10                    = New-Object system.Windows.Forms.Button
        $ExampleMaintenanceWindow10.text               = "Example Maintenance Window 10"
        $ExampleMaintenanceWindow10.width              = 178
        $ExampleMaintenanceWindow10.height             = 30
        $ExampleMaintenanceWindow10.location           = New-Object System.Drawing.Point(302,210)
        $ExampleMaintenanceWindow10.Font               = 'Microsoft Sans Serif,10'
        $ExampleMaintenanceWindow10.add_Click($ExampleMaintenanceWindow10Click)

        $Form.controls.AddRange(@($Title,$ExampleMaintenanceWindow1,$ExampleMaintenanceWindow2,$ExampleMaintenanceWindow3,$ExampleMaintenanceWindow4,$ExampleMaintenanceWindow5,$ExampleMaintenanceWindow6,$ExampleMaintenanceWindow7,$ExampleMaintenanceWindow8,$ExampleMaintenanceWindow9,$ExampleMaintenanceWindow10))
        # This command is what runs the GUI.
        $Form.ShowDialog() | Out-Null
        Write-Host "Server added to the selected window." -ForegroundColor Green -BackgroundColor Black
    }
}