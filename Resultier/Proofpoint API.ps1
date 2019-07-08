$Org = Read-Host "Organization"
$Username = Read-Host "Username"
$Pass = Read-Host "Password"
$ProofpointHeader = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
$ProofpointHeader.Add("X-User","$Username")
$ProofpointHeader.Add("X-Password","$pass")
$endpointuri = "https://us3.proofpointessentials.com/api/endpoint/$org"
$endpointresults = Invoke-RestMethod -Uri $endpointuri -Headers $ProofpointHeader -Method GET
$endpoint = $endpointresults.message.endpoints
$Uri = "$endpoint/api/orgs/$org/users"
$ProofpointHeader.Add("Content-Type","application/json")
$users = Import-Csv "C:\AMD\testorg.csv" | ConvertTo-Json
Invoke-RestMethod -uri $uri -Headers $ProofpointHeader -Method POST -Body $users -ContentType "application/json"
$Username = ""
$Pass = ""
$ProofpointHeader = ""