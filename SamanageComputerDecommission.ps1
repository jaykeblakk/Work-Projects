#######################################################
# Computer decommissioning script for Agri-Service, LLC
# Written by Coby Carter, with credit to Greg Rowe for
# API Header creation help
#######################################################
# This script is designed to allow the user to perform
# the task of decommissioning computers without the
# need to manually find each computer and change
# the status in Samanage. 

# This script can be run with a GUI that will allow you 
# to drag and drop a file with names in it to use for 
# your decommissioning.
 
# You can also just allow the script to scrape LogMeIn
# API's and pull the information from there.

function Decommission-Computer
{
    <# Uncomment this for a drag and drop GUI
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")


    ### Create form ###

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "PowerShell GUI"
    $form.Size = '260,320'
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = $form.Size
    $form.MaximizeBox = $False
    $form.Topmost = $True


    ### Define controls ###

    $button = New-Object System.Windows.Forms.Button
    $button.Location = '5,5'
    $button.Size = '75,23'
    $button.Width = 230
    $button.Text = "Decomission"

    $label = New-Object Windows.Forms.Label
    $label.Location = '5,40'
    $label.AutoSize = $True
    $label.Text = "Drop files or folders here:"

    $listBox = New-Object Windows.Forms.ListBox
    $listBox.Location = '5,60'
    $listBox.Height = 200
    $listBox.Width = 240
    $listBox.Anchor = ([System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top)
    $listBox.IntegralHeight = $False
    $listBox.AllowDrop = $True

    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Text = "Ready"


    ### Add controls to form ###

    $form.SuspendLayout()
    $form.Controls.Add($button)
    $form.Controls.Add($label)
    $form.Controls.Add($listBox)
    $form.Controls.Add($statusBar)
    $form.ResumeLayout()


    ### Write event handlers ###

    $button_Click = {#>
        $Token = "WOWTHATSALONGTOKEN"
        $SamanageHeader = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
        $SamanageHeader.Add("X-Samanage-Authorization","Bearer $Token")
        $SamanageHeader.Add("Accept","application/vnd.samanage.v2.1+json")

        $computers1 = Invoke-WebRequest -Headers $SamanageHeader -Uri "https://api.samanage.com/hardwares.json?status=-1&report_id=0000000&page=1"
        $computers1 = $computers1.content | convertfrom-Json
        $computers2 = Invoke-WebRequest -Headers $SamanageHeader -Uri "https://api.samanage.com/hardwares.json?status=-1&report_id=0000000&page=2"
        $computers2 = $computers2.content | convertfrom-Json
        $computers3 = Invoke-WebRequest -Headers $SamanageHeader -Uri "https://api.samanage.com/hardwares.json?status=-1&report_id=0000000&page=3"
        $computers3 = $computers3.content | convertfrom-Json
        $computers4 = Invoke-WebRequest -Headers $SamanageHeader -Uri "https://api.samanage.com/hardwares.json?status=-1&report_id=0000000&page=4"
        $computers4 = $computers4.content | convertfrom-Json
        $computers5 = Invoke-WebRequest -Headers $SamanageHeader -Uri "https://api.samanage.com/hardwares.json?status=-1&report_id=0000000&page=5"
        $computers5 = $computers5.content | convertfrom-Json
        $computers6 = Invoke-WebRequest -Headers $SamanageHeader -Uri "https://api.samanage.com/hardwares.json?status=-1&report_id=0000000&page=6"
        $computers6 = $computers6.content | convertfrom-Json

        $totalcomputers = ""
        $totalcomputers = $computers1 | select name, id, @{ label="Status"; e={ $_.status.name } }
        $totalcomputers += $computers2 | select name, id, @{ label="Status"; e={ $_.status.name } }
        $totalcomputers += $computers3 | select name, id, @{ label="Status"; e={ $_.status.name } }
        $totalcomputers += $computers4 | select name, id, @{ label="Status"; e={ $_.status.name } }
        $totalcomputers += $computers5 | select name, id, @{ label="Status"; e={ $_.status.name } }
        $totalcomputers += $computers6 | select name, id, @{ label="Status"; e={ $_.status.name } }

        $decommissionbody = "{
            `"hardware`":{
                `"status`":{
                    `"name`":`"Disposed`"
                }
            }
        }"
        # If you want to use the GUI, comment the below portion out.
        $companyID = '0000000000'
        $psk = 'WOWTHATSALONGTOKEN'
        $Uri = 'https://secure.logmein.com/public-api/v2/hostswithgroups'
        
        $LogMeInHeader = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
        $LogMeInHeader.Add('Accept','application/JSON + ";" + "charset=utf-8"')
        $LogMeInHeader.Add('Authorization', "{`"companyId`":${companyID}, `"psk`":`"$psk`"}")
        $groups = Invoke-RestMethod -Uri $Uri -Headers $LogMeInHeader -Method GET
        
        $oldcomputerid = $groups.groups | where {$_.name -eq "Old Computers (Refreshed)"} | select id
        $computersingroup = $groups.hosts | where {$_.groupid -eq $oldcomputerid.id} | select description, id
        $computers = $computersingroup.description
        $computerids = $computersingroup.id
        $excelpath = "C:\Users\ccarter\Agri-Service\Information Technology - Documents\Projects\PC Refresh\RefreshedComputerList.xlsx"
        $computersingroup | Export-Excel -Path $excelpath -AutoSize -AutoFilter

        
        # You will need the below line if you decide to use the GUI.
        # $names = Get-Content $listBox.Items
        $ids = ""
        $ids = foreach ($computer in $computers){($totalcomputers | where {$_.name -eq $computer} | select id)}
        foreach ($id in $ids)
        {
            $hardwareid = $id.id
            $updateuri = "https://api.samanage.com/hardwares/$hardwareid.json"
            Invoke-WebRequest -Headers $Header -Uri $updateuri -Method PUT -Body $decommissionbody -ContentType "application/json"
        }
        foreach ($id in $computerids)
        {
            $int64id = [int64]$id
            $ints += "$int64id,"
        }
        $json = "{
            `"hostIds`" : [$ints]
        }"
        $deleteuri = "https://secure.logmein.com/public-api/v1/hosts"
        # Won't work because I need to convert them to int64's
        Invoke-RestMethod -Uri $deleteuri -Method Delete -Body $json -Headers $LogMeInHeader
        <#$form.Close()
    }
    
    $listBox_DragOver = [System.Windows.Forms.DragEventHandler]{
        if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) # $_ = [System.Windows.Forms.DragEventArgs]
        {
            $_.Effect = 'Copy'
        }
        else
        {
            $_.Effect = 'None'
        }
    }
        
    $listBox_DragDrop = [System.Windows.Forms.DragEventHandler]{
        foreach ($filename in $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) # $_ = [System.Windows.Forms.DragEventArgs]
        {
            $listBox.Items.Add($filename)
        }
        $statusBar.Text = ("List contains $($listBox.Items.Count) items")
    }

    $form_FormClosed = {
        try
        {
            $listBox.remove_Click($button_Click)
            $listBox.remove_DragOver($listBox_DragOver)
            $listBox.remove_DragDrop($listBox_DragDrop)
            $listBox.remove_DragDrop($listBox_DragDrop)
            $form.remove_FormClosed($Form_Cleanup_FormClosed)
        }
        catch [Exception]
        { }
    }


    ### Wire up events ###

    $button.Add_Click($button_Click)
    $listBox.Add_DragOver($listBox_DragOver)
    $listBox.Add_DragDrop($listBox_DragDrop)
    $form.Add_FormClosed($form_FormClosed)


    #### Show form ###

    [void] $form.ShowDialog()
    #>
}