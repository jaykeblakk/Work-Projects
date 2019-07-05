function Create-Customer
{
    $key = get-content "resultier/stripekey.txt"
    $Uri = "https://api.stripe.com/v1/customers"
    $StripeHeader = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $StripeHeader.Add("Authorization","Bearer $key")
    $stripebody = @{
        description="Test for Stripe API";
        name="API Test";
        email="coby@resultier.com"; }
    $stripeinfo = Invoke-RestMethod -uri $uri -Headers $StripeHeader -Method POST -body $stripebody
    $customerid = $stripeinfo.id
    $sourceuri = "https://api.stripe.com/v1/sources"
    $sourcebody = @{
        type="card";
        currency="usd";
    }
    $sourceinfo = Invoke-RestMethod -uri $sourceuri -Headers $StripeHeader -Method POST -body $sourcebody
    $sourceinfo
}

function Delete-Customer
{
    $key = get-content "resultier/stripekey.txt"
    $customerid = read-host "ID"
    $Uri = "https://api.stripe.com/v1/customers/$customerid"
    $StripeHeader = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $StripeHeader.Add("Authorization","Bearer $key")
    $stripeinfo = Invoke-RestMethod -uri $uri -Headers $StripeHeader -Method DELETE
    $stripeinfo
}