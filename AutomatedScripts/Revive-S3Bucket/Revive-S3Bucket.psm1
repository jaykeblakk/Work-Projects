function Revive-S3Bucket()
{
    # Set the name of the S3 bucket to be restored
    $bucket = "S3bucketname"
    
    # Set the endpoint URL of the S3 service
    $endpointurl = "https://s3endpoint.example.com"
    
    # Region is set as us-east-1 because that's the default region for local endpoints. This is what increases the speed of the script.
    $region = "us-east-1"
    
    # Retrieve the versions of objects in the specified S3 bucket
    # The result is piped to select the "versions" property
    #$versions = get-s3version -bucketname $bucket -endpointurl $endpointurl -region $region | select versions
    
    # Filter the versions to select only the delete markers
    # The filtered delete markers are piped to select the "key" and "versionid" properties
    #$objects = $versions.versions | where isdeletemarker -eq "$true" | select key, versionid

    # Initialize variables for pagination
    $maxKeys = 1000
    $objects = @()
    $nextMarker = $null

    do {
        # Retrieve a batch of object versions
        $response = get-s3version -bucketname $bucket -endpointurl $endpointurl -region $region -MaxKeys $maxKeys -KeyMarker $nextMarker
        
        # Extract the delete markers from the response
        $deleteMarkers = $response.Versions | where isdeletemarker -eq "$true" | select key, versionid
        
        # Add the delete markers to the objects array
        $objects += $deleteMarkers
        
        # Update the next marker for pagination
        $nextMarker = $response.NextKeyMarker
    } while ($nextMarker)
    
    # Iterate over each delete marker object
    foreach ($object in $objects)
    {   
        # Remove the delete marker using the remove-s3object cmdlet
        # Pass the bucket name, endpoint URL, object key, version ID, and region as parameters
        # The -confirm:$false parameter is used to suppress confirmation prompts
        remove-s3object -bucketname $bucket -endpointurl $endpointurl -key $object.key -versionid $object.versionid -region $region -confirm:$false
        
        # Display the object key of the restored object (not required)
        Write-Host "`r`nObject: $($object.key)"
        
        # Display the version ID of the restored object (not required)
        Write-Host "ID: $($object.versionid)"
    }
    
    # Retrieve the objects in the specified S3 bucket after restoration
    # Pass the bucket name, endpoint URL, and region as parameters (Also not required)
    get-s3object -BucketName $bucket -EndpointUrl $endpointurl -region $region
}