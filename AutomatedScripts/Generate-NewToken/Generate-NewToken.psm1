function Generate-NewToken()
{
    $rubriktoken = get-content C:\Scripts\rubriktoken.txt
    Connect-Rubrik -Server rubrikurl.example.com -Token $rubriktoken
    $newtoken = New-RubrikAPIToken -expiration 11520 -Tag "scripting-token"
    $newtoken = $newtoken.Token
    Set-Content C:\Scripts\rubriktoken.txt -content $newtoken
}