function Delete-S3Objects()
{
    # Set the name of the S3 bucket to be restored
    $bucket = "S3bucketname"
    
    # Set the endpoint URL of the S3 service
    $endpointurl = "https://s3endpoint.example.com"
    
    # Region is set as us-east-1 because that's the default region for local endpoints. This is what increases the speed of the script.
    $region = "us-east-1"
    $objectname = Read-Host "Please enter the name of the object you want deleted"
    get-s3object -Name $objectname -BucketName $bucket -EndpointUrl $endpointurl -region $region
    Remove-s3object -name $objectname -BucketName $bucket -endpointurl $endpointurl -region $region
}