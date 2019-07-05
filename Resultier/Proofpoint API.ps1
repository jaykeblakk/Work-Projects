$Username = Read-Host "Username"
$Pass = Read-Host "Password"
$Uri = "https://us3.proofpointessentials.com/api/orgs/resultier.com/users"
$ProofpointHeader = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
$ProofpointHeader.Add("X-User","$Username")
$ProofpointHeader.Add("X-Password","$pass")
$ProofpointHeader.Add("Content-Type","application/json")
$users = Import-Csv "C:\AMD\test.csv" | ConvertTo-Json
Invoke-RestMethod -uri $uri -Headers $ProofpointHeader -Method POST -Body $users -ContentType "application/json"
$Username = ""
$Pass = ""
$ProofpointHeader = ""