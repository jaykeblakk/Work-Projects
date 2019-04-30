$Username = Read-Host "Username"
$Pass = Read-Host "Password"
$Uri = "https://us1.proofpointessentials.com/api/v1/endpoints/resultier.com"
$ProofpointHeader = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
$ProofpointHeader.Add("X-User","$Username")
$ProofpointHeader.Add("X-password","$pass")
Invoke-RestMethod -uri $uri -Headers $ProofpointHeader -Method GET
$Username = ""
$Pass = ""