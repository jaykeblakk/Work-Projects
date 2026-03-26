function Zip-Files()
{
    $path = "C:\temp\datelist.txt"
    $dates = get-content $path
    $jobs = foreach($date in $dates)
    {
    start-threadjob {Write-Host "Beginning zipping for $using:date"; Zip-Files($using:date) } -throttlelimit 10
    }
    foreach ($job in $jobs){Receive-job $job -wait -autoremovejob}
}