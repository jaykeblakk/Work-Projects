Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

function New-365User() 
{
    [CmdletBinding()]
    param()
    $ErrorActionPreference = "SilentlyContinue"
    # Variables

    $CreateButton_OnClick=
    {
        $Name = $NameBox.Text
        $DisplayName = $NameBox.Text
        if($VantageRadioButton.Checked -eq $true)
        {
            $Domain = '@domain1.com'
        }
        else
        {
            $Domain = '@domain2.com'
        }
        $EmailName = $Name.replace(' ', '')
        $Email = $EmailName + $Domain
        $Title = $TitleBox.Text
        $Dept = $DepartmentBox.Text
        $Store = $StoreBox.Text
        if ($Store -eq "Logan/Hyde Park")
        {
            $Store = "Logan"
        }
        if ($Store -eq "Burley/Heyburn")
        {
            $Store = "Burley"
        }
        if ($E3Button.Checked -eq $true)
        {
            $license = "E3licensefromexchange"
        }
        else
        {
            $license = "E1licensefromexchange"
        }
        $FirstName = $Name.Split(' ')[0]
        #$Pass = $password
        $UserInfo =
        @{
            Name = $Name
            DisplayName = $DisplayName
            Email = $Email
            Title = $Title
            Department = $Dept
            UsageLocation = "US"
            LicenseAssignment = $license
            Password = $Pass
            ForceChangePassword = $false
        }
        Connect-Services
        Create-User @UserInfo
        Write-Host ""
        Write-Host "Updating and opening the Excel Spreadsheet..." -ForegroundColor Yellow -BackgroundColor black
        $excel = new-excel -path "S:\New Users\Template\passwords.xlsx"
        $excel | get-worksheet | Set-CellValue -Coordinates B1:B1 -Value "$Name"
        $excel | get-worksheet | Set-CellValue -Coordinates B4:B4 -Value "$Email"
        $excel | get-worksheet | Set-CellValue -Coordinates B5:B5 -Value "$Pass"
        switch ($store)
        {
            "Twin Falls"      {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Buhl"            {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Burley/Heyburn"  {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Logan/Hyde Park" {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Sugar City"      {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Terreton"        {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Roosevelt"       {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Marsing"         {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Blackfoot"       {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Fruitland"       {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Pasco"           {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
            "Eltopia"         {$excel | get-worksheet | Set-CellValue -Coordinates B14:B14 -Value "REDACTED"}
        }
        $path = "\\HOSTNAME\SHARE\$Name.xlsx"
        $excel | Save-Excel -Path $path -Passthru
        Write-Host "New spreadsheet created. Saved in $path" -ForegroundColor yellow -BackgroundColor black
        start-process $path
        Write-Host "`n"
        $UserProgressBar.Visible = $true
        $ProgressBarText.Visible = $true
        For($i=120; $i -gt 0; $i--)
        {
            $UserProgressBar.PerformStep()
            Start-Sleep -Seconds 1
        }
                # Add to distribution groups. This checks through because of different names for each group. It looks at the store and department to determine which two it needs to join from there. After that, it adds their Email (DistinguishedName) to the group. #
        if ($Dept -eq "Parts")
        {
            Add-DistributionGroupMember -Identity "$Store Store" -Member "$Email"
            Write-Host "$Name has been added to the $Store Store group."
            if($Store -eq "Twin Falls")
            {
                $Store = "Twin"
            }
            Add-DistributionGroupMember -Identity "$Store Parts" -Member "$Email"
            Write-Host "$Name has been added to the $Store Parts group."
        }
        elseif ($Dept -eq "Service")
        {
            Add-DistributionGroupMember -Identity "$Store Store" -Member "$Email"
            Write-Host "$Name has been added to the $Store Store group."
            Add-DistributionGroupMember -Identity "$Store Service" -Member "$Email"
            Write-Host "$Name has been added to the $Store Service group."
        }
        elseif ($Dept -eq "Sales")
        {
            Add-DistributionGroupMember -Identity "$Store Store" -Member "$Email"
            Write-Host "$Name has been added to the $Store Store group."
            Add-DistributionGroupMember -Identity "Sales" -Member "$Email"
            Write-Host "$Name has been added to the Sales group."
            Add-DistributionGroupMember -Identity "Salesmen Meeting" -Member "$Email"
            Write-Host "$Name has been added to the Salesmen Meeting group."
        }
        else
        {
            Write-Host -fore red -BackgroundColor black "Department or Store not recognized. Please assign these manually within the O365 Administration Portal"
        }
        Get-PSSession | Remove-PSSession
        $Form.close()
    }
    ##########################################

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.text                       = "Create a new user in Office 365"
    $Form.ClientSize                 = '400,400'
    $Form.BackColor                  = "#4a90e2"
    $Form.TopMost                    = $false
    $Form.AutoSize                   = $true

    $NameLabel                       = New-Object system.Windows.Forms.Label
    $NameLabel.text                  = "Name"
    $NameLabel.AutoSize              = $true
    $NameLabel.width                 = 25
    $NameLabel.height                = 10
    $NameLabel.location              = New-Object System.Drawing.Point(7,5)
    $NameLabel.Font                  = 'Microsoft Sans Serif,10'

    $NameBox                         = New-Object system.Windows.Forms.TextBox
    $NameBox.multiline               = $false
    $NameBox.width                   = 250
    $NameBox.height                  = 20
    $NameBox.Anchor                  = 'top,right,bottom,left'
    $NameBox.location                = New-Object System.Drawing.Point(7,28)
    $NameBox.Font                    = 'Microsoft Sans Serif,10'
    $NameBox.TabIndex                 = '0'
    $NameBox.TabStop                 = $true

    $TitleLabel                      = New-Object system.Windows.Forms.Label
    $TitleLabel.text                 = "Title"
    $TitleLabel.AutoSize             = $true
    $TitleLabel.width                = 25
    $TitleLabel.height               = 10
    $TitleLabel.location             = New-Object System.Drawing.Point(6,53)
    $TitleLabel.Font                 = 'Microsoft Sans Serif,10'

    $Titlebox                        = New-Object system.Windows.Forms.TextBox
    $Titlebox.multiline              = $false
    $Titlebox.width                  = 200
    $Titlebox.height                 = 20
    $Titlebox.Anchor                 = 'top,right,bottom,left'
    $Titlebox.location               = New-Object System.Drawing.Point(7,75)
    $Titlebox.Font                   = 'Microsoft Sans Serif,10'
    $Titlebox.TabIndex                 = '1'
    $Titlebox.TabStop                 = $true

    $LicenseRadioGroup               = New-Object system.Windows.Forms.Groupbox
    $LicenseRadioGroup.height        = 57
    $LicenseRadioGroup.width         = 98
    $LicenseRadioGroup.Anchor        = ''
    $LicenseRadioGroup.location      = New-Object System.Drawing.Point(5,98)
    $LicenseRadioGroup.TabIndex         = '2'

    $LicenseLabel                    = New-Object system.Windows.Forms.Label
    $LicenseLabel.text               = "License"
    $LicenseLabel.AutoSize           = $true
    $LicenseLabel.width              = 25
    $LicenseLabel.height             = 10
    $LicenseLabel.Anchor             = ''
    $LicenseLabel.location           = New-Object System.Drawing.Point(10,9)
    $LicenseLabel.Font               = 'Microsoft Sans Serif,10'

    $E1Button                        = New-Object system.Windows.Forms.RadioButton
    $E1Button.text                   = "E1"
    $E1Button.AutoSize               = $true
    $E1Button.width                  = 104
    $E1Button.height                 = 20
    $E1Button.Anchor                 = ''
    $E1Button.location               = New-Object System.Drawing.Point(9,28)
    $E1Button.Font                   = 'Microsoft Sans Serif,10'


    $E3Button                        = New-Object system.Windows.Forms.RadioButton
    $E3Button.text                   = "E3"
    $E3Button.AutoSize               = $true
    $E3Button.width                  = 104
    $E3Button.height                 = 20
    $E3Button.Anchor                 = ''
    $E3Button.location               = New-Object System.Drawing.Point(52,28)
    $E3Button.Font                   = 'Microsoft Sans Serif,10'

    $DomainRadioGroup                = New-Object system.Windows.Forms.Groupbox
    $DomainRadioGroup.height         = 71
    $DomainRadioGroup.width          = 208
    $DomainRadioGroup.Anchor         = ''
    $DomainRadioGroup.location       = New-Object System.Drawing.Point(5,159)
    $DomainRadioGroup.TabStop         = $false
    $DomainRadioGroup.TabIndex         = '3'

    $DomainLabel                     = New-Object system.Windows.Forms.Label
    $DomainLabel.text                = "Domain"
    $DomainLabel.AutoSize            = $true
    $DomainLabel.width               = 37
    $DomainLabel.height              = 33
    $DomainLabel.Anchor              = ''
    $DomainLabel.location            = New-Object System.Drawing.Point(8,11)
    $DomainLabel.Font                = 'Microsoft Sans Serif,10'

    $AgriServiceDomainButton         = New-Object system.Windows.Forms.RadioButton
    $AgriServiceDomainButton.text    = "Agri-Service"
    $AgriServiceDomainButton.AutoSize  = $true
    $AgriServiceDomainButton.width   = 116
    $AgriServiceDomainButton.height  = 43
    $AgriServiceDomainButton.Anchor  = ''
    $AgriServiceDomainButton.location  = New-Object System.Drawing.Point(8,31)
    $AgriServiceDomainButton.Font    = 'Microsoft Sans Serif,10'

    $VantageRadioButton              = New-Object system.Windows.Forms.RadioButton
    $VantageRadioButton.text         = "domain1"
    $VantageRadioButton.AutoSize     = $true
    $VantageRadioButton.width        = 116
    $VantageRadioButton.height       = 43
    $VantageRadioButton.Anchor       = ''
    $VantageRadioButton.location     = New-Object System.Drawing.Point(108,31)
    $VantageRadioButton.Font         = 'Microsoft Sans Serif,10'

    $StoreLabel                      = New-Object system.Windows.Forms.Label
    $StoreLabel.text                 = "Store"
    $StoreLabel.AutoSize             = $true
    $StoreLabel.width                = 25
    $StoreLabel.height               = 10
    $StoreLabel.Anchor               = ''
    $StoreLabel.location             = New-Object System.Drawing.Point(6,241)
    $StoreLabel.Font                 = 'Microsoft Sans Serif,10'

    $StoreBox                        = New-Object system.Windows.Forms.ComboBox
    $StoreBox.width                  = 100
    $StoreBox.height                 = 20
    $StoreBox.Anchor                 = ''
    @('Twin Falls', 'Buhl','Burley/Heyburn','Logan/Hyde Park','Sugar City','Terreton','Roosevelt','Marsing','Blackfoot','Pasco','Eltopia', 'Fruitland') | ForEach-Object {[void] $StoreBox.Items.Add($_)}
    $StoreBox.location               = New-Object System.Drawing.Point(5,264)
    $StoreBox.Font                   = 'Microsoft Sans Serif,10'
    $StoreBox.TabIndex                 = '4'

    $DepartmentLabel                 = New-Object system.Windows.Forms.Label
    $DepartmentLabel.text            = "Department"
    $DepartmentLabel.AutoSize        = $true
    $DepartmentLabel.width           = 25
    $DepartmentLabel.height          = 10
    $DepartmentLabel.Anchor          = ''
    $DepartmentLabel.location        = New-Object System.Drawing.Point(129,241)
    $DepartmentLabel.Font            = 'Microsoft Sans Serif,10'

    $DepartmentBox                   = New-Object system.Windows.Forms.ComboBox
    $DepartmentBox.width             = 100
    $DepartmentBox.height            = 20
    $DepartmentBox.Anchor            = ''
    @('Parts','Sales','Service') | ForEach-Object {[void] $DepartmentBox.Items.Add($_)}
    $DepartmentBox.location          = New-Object System.Drawing.Point(129,264)
    $DepartmentBox.Font              = 'Microsoft Sans Serif,10'
    $DepartmentBox.TabIndex             = '5'

    $CreateButton                    = New-Object system.Windows.Forms.Button
    $CreateButton.BackColor          = "#50e3c2"
    $CreateButton.text               = "Create"
    $CreateButton.width              = 60
    $CreateButton.height             = 30
    $CreateButton.Anchor             = 'bottom'
    $CreateButton.location           = New-Object System.Drawing.Point(45,349)
    $CreateButton.Font               = 'Microsoft Sans Serif,10'
    $CreateButton.TabIndex             = '6'
    $CreateButton.add_Click($CreateButton_OnClick)

    $CancelButton                    = New-Object system.Windows.Forms.Button
    $CancelButton.BackColor          = "#9b9b9b"
    $CancelButton.text               = "Cancel"
    $CancelButton.width              = 60
    $CancelButton.height             = 30
    $CancelButton.Anchor             = 'bottom'
    $CancelButton.location           = New-Object System.Drawing.Point(240,349)
    $CancelButton.Font               = 'Microsoft Sans Serif,10'
    $CancelButton.TabIndex             = '7'
    $CancelButton.add_Click({$Form.Close()})

    $UserProgressBar                 = New-Object system.Windows.Forms.ProgressBar
    $UserProgressBar.width           = 380
    $UserProgressBar.height          = 14
    $UserProgressBar.Anchor          = 'top,right,bottom,left'
    $UserProgressBar.location        = New-Object System.Drawing.Point(5,306)
    $UserProgressBar.Style             = "Continuous"
    $UserProgressBar.Minimum         = 0
    $UserProgressBar.Maximum         = 120
    $UserProgressBar.Value             = 0
    $UserProgressBar.Step             = 1
    $UserProgressBar.Visible         = $false

    $ProgressBarText                 = New-Object system.Windows.Forms.Label
    $ProgressBarText.text            = "User created! Waiting 120 seconds to add them to Distribution Groups..."
    $ProgressBarText.AutoSize        = $true
    $ProgressBarText.width           = 25
    $ProgressBarText.height          = 10
    $ProgressBarText.location        = New-Object System.Drawing.Point(5,325)
    $ProgressBarText.Font            = 'Microsoft Sans Serif,8'
    $ProgressBarText.Visible         = $false

    $Form.controls.AddRange(@($LicenseRadioGroup,$DomainRadioGroup,$NameLabel,$TitleLabel,$Titlebox,$StoreLabel,$StoreBox,$NameBox,$DepartmentLabel,$DepartmentBox,$CreateButton,$CreateAndNewButton,$CancelButton,$UserProgressBar,$ProgressBarText))
    $LicenseRadioGroup.controls.AddRange(@($LicenseLabel,$E1Button,$E3Button))
    $DomainRadioGroup.controls.AddRange(@($DomainLabel,$AgriServiceDomainButton,$VantageRadioButton))

    $E1Button.Add_CheckedChanged({  })

    $E1Button.Checked                 = $true
    $AgriServiceDomainButton.Checked  = $true

    [void][System.Windows.Forms.Application]::Run($Form)
}
