function New-Live-Stream(
    [Parameter(Mandatory,
    HelpMessage="A name prefix used for resource groups, storage accounts, and stream resources in Azure")]
    [string]$Name
){

    $groupName = $Name
    $storageAcc = $groupName.toLower() -replace '[^a-z]', ''
    $amsAcc = "ams$groupName" -replace '[^a-z0-9]', ''
    $eventName = "$groupName-event"
    $creationGUID = [guid]::NewGuid();
    $assetName = "$groupName-asset-$creationGUID"
    $outputName = "$groupName-output"

    Write-Host "Creating Accounts"
    # Create necessary accounts
    $groupCreated = az group create --name $groupName -l eastus --only-show-errors
    $storagrCreated = az storage account create --name "$storageAcc" -g $groupName --only-show-errors
    $amsCreated = az ams account create --name $amsAcc --storage-account $storageAcc -g $groupName --only-show-errors

    if (!$groupCreated -or !$storagrCreated -or !$amsCreated) {
        Write-Host "Account Created failed" -ForegroundColor Red
        exit
    }

    Write-Host "Getting Default Streaming Endpoint"

    $streamingEndpointIsEnabled = $false

    Start-Sleep -s 10
    do
    {
        try {
            Write-Host "Waiting for resource to be created"
            Start-Sleep -s 5
            
            Write-Host "Attempting to start the streaming endpoint"
            
            $streamingEndpoint =  az ams streaming-endpoint list -g $groupName -a $amsAcc --only-show-errors --query "[*].{id:id, name:name}"  | ConvertFrom-Json
            $response = az ams streaming-endpoint start --ids $streamingEndpoint.id --only-show-errors | ConvertFrom-Json

            if ($response) {
                $streamingEndpointIsEnabled = $true
            }
        }
        catch {
            
            # Write-Host $_
        }
    } while ($streamingEndpointIsEnabled -eq $false)


    Write-Host "Creating live event" -ForegroundColor White
    # Don't use AllowAll in production
    $liveEvent = az ams live-event create --name $eventName -g $groupName -a $amsAcc --streaming-protocol RTMP --ips AllowAll --vanity-url true --access-token $creationGUID --query "{id: id, name: name}" | ConvertFrom-Json

    # Start the live event
    $endpoints = az ams live-event start --ids $liveEvent.id --query "{input:input.endpoints, previewURL: preview.endpoints[0].url}" | ConvertFrom-Json
    $ingressEndpoint = $endpoints.input[0]

    Write-Host "Create Asset, Live-Output, and Streaming Locator"
    $asset = az ams asset create -g $groupName -a $amsAcc --name $assetName --query "{name:name}" | ConvertFrom-Json
    $output = az ams live-output create -g $groupName -a $amsAcc --live-event-name $eventName --name $outputName --asset-name $asset.name --archive-window-length PT10M --query "{id: id}" | ConvertFrom-Json
    $locator = az ams streaming-locator create -g $groupName -a $amsAcc --asset-name $assetName --name "streaming-locator" --streaming-policy-name "Predefined_ClearStreamingOnly"  | ConvertFrom-Json

    Write-Host "Start streaming to warm up outputs, then continue script"
    Write-Host "Endpoint to stream to:"
    Write-Host $ingressEndpoint.url
    Pause

    #TODO: I've tested this manually and it works. The TCP request fails when the script runs,
    #      which leaves me to believe we have more resource checking loops to do. 
    # For now, we'll just have to pause and wait for a stream to start.
    # Write-Host "Stream blank mp4 to outputs available"
    # ffmpeg -v verbose -i "F:\blank.mkv" -strict -2 -c:a aac -b:a 128k -ar 44100 -r 30 -g 60 -keyint_min 60 -b:v 400000 -c:v libx264 -preset medium -bufsize 400k -maxrate 400k -f flv "$($ingressEndpoint.url)/mystream"

    Write-Host "Getting streaming paths"
    # Once you're streaming, get the generated paths for your output
    $streams = az ams streaming-locator get-paths --ids $locator.id  |ConvertFrom-Json
    $hls = $streams.streamingPaths | Where streamingProtocol -eq "Hls" | Select paths
    $hlsURL = $hls.paths[0]
    $streamURL = "https://$amsAcc-usea.streaming.media.azure.net$hlsURL"

    Write-Host ""
    Write-Host ""
    Write-Host "Ingress URL:" -ForegroundColor Green
    Write-Host $ingressEndpoint.url -ForegroundColor Green
    Write-Host ""
    Write-Host "Livestream URL:" -ForegroundColor Green
    Write-Host $streamURL -ForegroundColor Green

    Write-Host "Generating Static Site"
    (Get-Content -path .\web\index-template.html -Raw) -replace 'SOURCE_URL', $streamURL | Set-Content .\web\index.html

    Write-Host "Publishing Static Site"
    az storage blob service-properties update --account-name $storageAcc --static-website --404-document 404.html --index-document index.html
    
    $webUpload = az storage blob upload-batch --account-name $storageAcc -s ./web -d '$web'
    if (!$webUpload) {
        Write-Host "Upload Failed" -ForegroundColor Red
    }

    Write-Host "Static Site URL:"
    Write-Host "https://$storageAcc.z13.web.core.windows.net/"
    
    Write-Host "Ingress URL:"
    Write-Host $ingressEndpoint.url

}


function Remove-Live-Stream (
    [Parameter(Mandatory,
    HelpMessage="The name you used when creating the live stream")]
    [string]$Name
) {
    $amsAcc = "ams$Name" -replace '[^a-z0-9]', ''
    az ams account delete -g $Name --name $amsAcc
    az group delete  -g $Name
    
}

Function Pause ($Message = "Press any key to continue . . . ") {
    if ((Test-Path variable:psISE) -and $psISE) {
        $Shell = New-Object -ComObject "WScript.Shell"
        $Button = $Shell.Popup("Click OK to continue.", 0, "Script Paused", 0)
    }
    else {     
        Write-Host -NoNewline $Message
        [void][System.Console]::ReadKey($true)
        Write-Host
    }
}