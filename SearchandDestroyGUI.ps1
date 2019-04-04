##########################################################################
# Search and Destroy for O365 Emails
# Written by Coby Carter
# Credit to Greg Rowe for the idea and commands
# 
# This script will create a function on your computer called SearchandDestroy 
# that will allow you to find a specific message that was sent out to your entire 
# organization and delete it from their mailboxes without the need to log in 
# to each inbox.
#########################################################################


#####################################

# To run this script, you must install the Exchange Online Powershell Console. Instructions for that installation are found at the link below:
# https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/connect-to-exchange-online-powershell/mfa-connect-to-exchange-online-powershell?view=exchange-ps

######################################
function Test-Reporting
{
	$mailboxlist = "NAME1@DOMAIN.COM","NAME2@DOMAIN.COM","NAME3@DOMAIN.COM"
	$searchquery = "subject:Test Email AND from:NAME4@DOMAIN.COM AND This is a test email. I hope that I can find this, and that Tony's doesn't have it."
	$TargetMailbox = 'NAME4@DOMAIN.COM'
	$TargetFolder = 'Search and Destroy Results'
	$mailboxlist | get-mailbox | Search-Mailbox -searchquery $searchquery -targetmailbox $targetmailbox -targetfolder $TargetFolder -Force	
}
function SearchandDestroy
{
	cls
	Write-Host "Checking to see if you have the latest ImportExcel module installed..."
	$excelmodule = get-module ImportExcel
	$excelmoduleonline = find-module ImportExcel
	if ($excelmodule -ne $excelmoduleonline)
	{
		Write-Host "Latest version of ImportExcel not installed! Updating module..."
		Install-Module ImportExcel -Force -Confirm:$false
	}
	# Imports an EXOPSession to allow this to run outside of an actual EXOP Powershell Console.
	Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse ).FullName|?{$_ -notmatch "_none_"}|select -First 1)
	$EXOPSession = New-ExoPSSession
	Import-PSSession $EXOPSession

	Add-Type -AssemblyName System.Windows.Forms
	[System.Windows.Forms.Application]::EnableVisualStyles()

	$Form                            = New-Object system.Windows.Forms.Form
	$Form.ClientSize                 = '507,181'
	$Form.text                       = "Form"
	$Form.BackColor                  = "#E4E4E4"
	$Form.TopMost                    = $false

	$BodyText                        = New-Object system.Windows.Forms.TextBox
	$BodyText.width                  = 337
	$BodyText.height                 = 108
	$BodyText.Anchor                 = 'right,bottom'
	$BodyText.location               = New-Object System.Drawing.Point(13,53)
	$BodyText.Multiline              = $true

	$BodyTextLabel                   = New-Object system.Windows.Forms.Label
	$BodyTextLabel.text              = "Enter the body text of the email"
	$BodyTextLabel.AutoSize          = $true
	$BodyTextLabel.width             = 375
	$BodyTextLabel.height            = 32
	$BodyTextLabel.location          = New-Object System.Drawing.Point(14,12)
	$BodyTextLabel.Font              = 'Microsoft Sans Serif,10'

	$BodyTextLabel2                  = New-Object system.Windows.Forms.Label
	$BodyTextLabel2.text             = "Carriage returns create new AND statements"
	$BodyTextLabel2.AutoSize         = $true
	$BodyTextLabel2.width            = 25
	$BodyTextLabel2.height           = 10
	$BodyTextLabel2.location         = New-Object System.Drawing.Point(14,33)
	$BodyTextLabel2.Font             = 'Microsoft Sans Serif,10'

	$Button1                         = New-Object system.Windows.Forms.Button
	$Button1.BackColor               = "#7ed321"
	$Button1.text                    = "Submit"
	$Button1.width                   = 86
	$Button1.height                  = 30
	$Button1.location                = New-Object System.Drawing.Point(379,65)
	$Button1.Font                    = 'Microsoft Sans Serif,10'
	$Button1.add_Click({$Form.Close()})

	$Button2                         = New-Object system.Windows.Forms.Button
	$Button2.BackColor               = "#d0021b"
	$Button2.text                    = "Cancel"
	$Button2.width                   = 86
	$Button2.height                  = 30
	$Button2.location                = New-Object System.Drawing.Point(379,100)
	$Button2.Font                    = 'Microsoft Sans Serif,10'
	$Button2.add_Click({$Form.Close()})

	$Form.controls.AddRange(@($BodyText,$BodyTextLabel,$BodyTextLabel2,$Button1,$Button2))

    # Starts prompting for different information used in the script. The name can be entered together or apart.
	# SearchQuery syntax help found here: https://docs.microsoft.com/en-us/Exchange/policy-and-compliance/ediscovery/message-properties-and-search-operators
	$SearchQuery = ""
	$body = ""
	[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
	$title = 'Employee Email'
	$msg   = 'Enter the first and last name of an employee to check'
	$Fullname = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)
	$name = $fullname -replace ' ',''

	[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
	$title = 'Email Subject'
	$msg   = 'Enter the subject of the email'
	$Subject = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

	if ($Subject)
	{
		$SearchQuery = $SearchQuery + "subject:`"${subject}`""
	}

	[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
	$title = 'From Address'
	$msg   = 'Enter the from address'
	$From = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

	if ($From)
	{
		if ($SearchQuery)
		{
			$SearchQuery = $SearchQuery + " AND from:`"${from}`""
		}
		else
		{
			$SearchQuery = "from:`"${from}`""
		}
	}
	else 
	{
		$SearchQuery = $SearchQuery
	}

	# This shows the prompt for the Body Text
	[void]$Form.ShowDialog()

	if ($BodyText.Text)
	{
		if($SearchQuery)
		{
			$RawBodyText = $BodyText.Text
			$NewBodyText = $Rawbodytext -split("`r`n")
			foreach ($piece in $NewBodyText)
			{
				$quotedpiece = "`"${piece}`""
				$body = "$body AND $quotedpiece"
			}
			$SearchQuery = $SearchQuery + $body
		}
		else
		{
			$RawBodyText = $BodyText.Text
			$NewBodyText = $Rawbodytext -split("`r`n")
			foreach ($piece in $NewBodyText)
			{
				$quotedpiece = "`"${piece}`""
				$body = "$body AND $quotedpiece"
			}
			$SearchQuery = $body	
		}
	}
	else
	{
		$SearchQuery = $SearchQuery
	}

	[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
	$title = 'Attachments'
	$msg   = 'Enter the full name of the attachment. If none, put nothing'
	$Attachments = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

	if ($Attachments)
	{
		$SearchQuery = $SearchQuery + " AND attachment:'${Attachments}'"
	}
	else
	{
		$SearchQuery = $SearchQuery
	}

	[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
	$title = 'Search Query Verification'
	$msg   = "$SearchQuery`r`nIs this the correct query? y/n"
	$Querychoice = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

	if ($querychoice -eq 'n')
	{
		Write-Host "Please correct your query."
		break
	}

	[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
	$title = 'Deleted Mail Destination'
	$msg   = 'Enter the mailbox you want the deleted emails to be copied to'
	$TargetMailbox = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

	$TargetFolder = "Search and Destroy Results"
	$SearchParams = @{
		# Identity: mailbox to search
		Identity      = "$name@DOMAIN.COM"
		SearchQuery   = $SearchQuery
		# TargetMailbox: mailbox where mail matching the search queries will be copied
		TargetMailbox = $TargetMailbox
		# TargetFolder: folder name in the TargetMailbox that will hold the copies of the found mail.
		TargetFolder  = $TargetFolder
		Force         = $True
	}
	Search-Mailbox @SearchParams

	[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
	$title = 'Verification'
	$msg   = 'Did you select the correct message? y/n'
	$emailchoice = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

    if ($emailchoice -eq 'n')
    {
        Write-Host "Please select another employee or improve your search query."
    }
    else
    {
        Write-Host "Searching all company mailboxes and deleting the message using the specified query."
        $SearchParams = @{
		    SearchQuery   = $SearchQuery
		    TargetMailbox = $TargetMailbox
		    TargetFolder  = $TargetFolder
		    Force         = $True
            DeleteContent = $true
		}
		# Style for the HTML Table. The results are compiled into the table and then sent in an email.
		$style = "<style>
		TABLE {
			border-width 1px; 
			border-style: solid; 
			border-color: black; 
			border-collapse: collapse; 
			font-family: calibri;}
		TD {
			border-width: 1px; 
			padding: 5px; 
			border-style: solid; 
			border-color: black; 
			font-family: calibri}
		TH {
			border-width: 1px; 
			border-style: solid; 
			border-color: black; 
			padding: 5px; 
			background-color: deepskyblue; 
			font-family: calibri;}</style>"	

		# This results variable ends up as an HTML Table that you later send in an email.
		$results = Get-Mailbox | Search-Mailbox @SearchParams | 
		Select-Object @{name="Identity"; expression={$_.Identity+"@DOMAIN.COM"}}, @{name="Emails Deleted"; expression={$_.resultitemscount}}
		$table = $results | ConvertTo-Html -As Table -Head $style
		
		[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
		$title = 'Excel Folder Path'
		$msg   = 'Enter a folder path. For default, put nothing.'
		$folder = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)
		$dateandtime = Get-Date -format g | foreach {$_ -replace "/","."} | foreach {$_ -replace ":",""}
		$condition = New-conditionaltext '1' DarkGreen LightGreen
		$condition2 = New-Conditionaltext '0' DarkRed LightPink
		if ($folder)
		{
			$path = "$folder\$dateandtime.xlsx"	
		}
		else 
		{
			$path = "\\IPADDR\Public\Search and Destroy Reports\$dateandtime.xlsx"
		}
		$results | Export-Excel "$path" -AutoSize -AutoFilter -ConditionalFormat $condition, $condition2

		# Info for the email message. The SMTP server is found using this documentation:
		# https://docs.microsoft.com/en-us/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-office-3
		$EmailInfo = @{
			EmailSubject = "Search and Destroy Results"
			EmailBody 	  = "The Search and Destroy script has finished. The results are below and in the attached spreadsheet.`n`n$table"
			ToAddress    = "IT@DOMAIN.COM"
			FromAddress  = "SearchAndDestroy@DOMAIN.COM"
			SMTPServer   = ""
			SMTPPort     = 25
			Attachments   = $path
		}
		Send-MailMessage @EmailInfo
	}
}