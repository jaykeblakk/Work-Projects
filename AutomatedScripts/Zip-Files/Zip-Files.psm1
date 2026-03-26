<#
.SYNOPSIS
    Compresses files using 7zip and cleans up old archives.

.DESCRIPTION
    This script automates the daily compression of files using 7zip, moves the compressed 
    archives to appropriate year/month folders, and performs cleanup of archives from 2 days ago.

.NOTES
    Author: Coby Carter
    Last Updated: 11/22/2024

.EXAMPLE
    zip-files

    Note: Only files located in the folder 2 days from today's date will be deleted.
    Anything older than that will not be deleted.
#>
function zip-files()
{
$today = get-date
$yesterday = $today.AddDays(-1)
$month = $yesterday.month
$day = $yesterday.day
$year = $yesterday.year
if ($month -lt 10)
    {
        $month = $month.tostring("00")
    }
if ($day -lt 10)
    {
        $day = $day.tostring("00")
    }
cd "\\path\to\archive\folder\$year\$month\$day"
$7zipPath = "$env:ProgramFiles\7-Zip\7z.exe"
# Checks if the 7-Zip executable file exists at the specified path. If the file is not found, it throws an exception to abort the job. Just a precaution.
if (-not (Test-Path -Path $7zipPath -PathType Leaf)) {
    throw "7 zip file '$7zipPath' not found. Aborting job."                                                      }
Set-Alias 7zip $7zipPath
7zip a -tzip -mx4 -r "$day.zip"
get-item "$day.zip" | move-item -Destination "\\path\to\archive\folder\$year\$month"
$2daysago = $today.AddDays(-2)
$deletemonth = $2daysago.month
$deleteday = $2daysago.day
$deleteyear = $2daysago.year
# Ensures that the $deletemonth and $deleteday variables have a leading zero if they are less than 10 so that the numbers work in the folder paths.
if ($deletemonth -lt 10)
{
    $deletemonth = $deletemonth.tostring("00")
}
if ($deleteday -lt 10)
{
    $deleteday = $deleteday.tostring("00")
}
<#This code block performs the following actions:
1. Constructs the path to the directory that will be deleted ($deletepath).
2. Sets the source path for the robocopy operation to an empty directory ("C:\emptydir").
3. Constructs the path to the parent directory of the directory that will be deleted ($daydeletepath).
4. Deletes the contents of the folder using the MIR option on robocopy on an empty directory.
5. Changes the current directory to the parent directory of the directory that will be deleted.
6. Deletes the directory.#>
$deletepath =  "\\path\to\archive\folder\$deleteyear\$deletemonth\$deleteday"
$sourcepath = "C:\emptydir"
$daydeletepath = "\\path\to\archive\folder\$deleteyear\$deletemonth"
robocopy $sourcepath $deletepath /MIR /w:5 /r:3 /MT:128 /E
cd $daydeletepath
rmdir $deleteday -recurse -Force
}