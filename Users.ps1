function rse ()
{
    Get-PSSession | Remove-PSSession
}

function Connect-Services ()
{
    # Create the connections to both Exchange Online and Azure AD

    $tries = 0
    $CredsExist = $true
    while ($tries -lt 5)
    {
        # Connect to Azure AD. This requires a few specific programs and modules to be installed. Uses the Credential Object to log in if the Creds object exists. If this fails, it will display the message.
        Try
        {
            Connect-MsolService -Credential $Creds -ErrorAction Stop
            Write-Host "Connected to Azure AD." -ForegroundColor Green -BackgroundColor Black
        }
        catch
        {
            $FailedMessage = $_.Exception.Message
            Write-Host "$FailedMessage" -ForegroundColor Red -BackgroundColor Black
        }
        # Attempt to connect to Exchange Online by creating a Powershell session within the O365 servers and then importing the commands. The usual error that you get says that you have exceeded the maximum connections allowed. I've set it to explain this more simply and provide a bit more information for the user.
        try
        {
            Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse ).FullName|?{$_ -notmatch "_none_"}|select -First 1)
            $EXOPSession = New-ExoPSSession
            Import-PSSession $EXOPSession
            Write-Host "Connected to Exchange Online." -ForegroundColor Green -BackgroundColor Black
            break
        }
        catch
        {
            $FailedMessage2 = $_.Exception.Message
            if ($FailedMessage2 -like '*Fail to create a runspace because you have exceeded the maximum number of connections allowed*')
            {
                Write-Host "You currently have too many exchange PSSessions open to connect to the server. Try Get-PSSession|Remove-PSSession to remove them. Otherwise, the sessions will automatically close in 15 minutes." -ForegroundColor Red -BackgroundColor Black
            }
        }
        $tries++
        # Will only attempt to connect 5 times. If it fails all 5 times, it will quit attempting the connections.
        if ($tries -eq 5)
        {
            Write-Host "`nUnable to connect to the required services. You may have too many current sessions open in Exchange online, or you have incorrect credentials. Please verify that your credentials are correct, and if they are, try again later." -ForegroundColor Red -BackgroundColor Black
            return
        }
    }
}
function Create-User()
{
    # Creates the parameters used to create a new user in O365. The Name, Email, Title, License, and Password are the only parameters that need to be initialized properly.
    Param
    (
        [string]$Name,
        [string]$DisplayName,
        [string]$Email,
        [string]$title,
        [string]$Department,
        [string]$UsageLocation,
        [string]$LicenseAssignment,
        [string]$password,
        [bool]$ForceChangePassword,
        [string]$store
    )
    $FirstName = $Name.Split(' ')[0]
    $LastName = $Name.Split(' ')[1]

    # Assign the parameters to their correct values in the hash table
        $User = 
        @{
            UserPrincipalName = $Email
            FirstName = $FirstName
            LastName = $LastName
            DisplayName = $Name
            ForceChangePassword = $ForceChangePassword
            Title = $Title
            UsageLocation = "US"
            LicenseAssignment = $LicenseAssignment
            Password = $password
        }
        Write-Host ""
        Write-Host "Updating and opening the Excel Spreadsheet..." -ForegroundColor Yellow -BackgroundColor black
        $excel = new-excel -path "S:\New Users\Template\passwords.xlsx"
        $excel | get-worksheet | Set-CellValue -Coordinates B1:B1 -Value "$Name"
        $excel | get-worksheet | Set-CellValue -Coordinates B4:B4 -Value $User.UserPrincipalName
        $excel | get-worksheet | Set-CellValue -Coordinates B5:B5 -Value $User.password
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
        $path = "\\SERVER\SHARE\$Name.xlsx"
        $excel | Save-Excel -Path $path -Passthru
        Write-Host "New spreadsheet created. Saved in $path" -ForegroundColor yellow -BackgroundColor black
        start-process $path
        Write-Host "`n"

        # Splat the hash table to the New-MsolUser command. #
        try
        {
            New-MsolUser @User
        }
        catch
        {
            $UserFail = $_.Exception.Message
            Write-Host $UserFail
            rse
            return
        }
        Write-Host "The O365 User for $Name has been created! Waiting 120 seconds to add them to Distribution Groups..."
}