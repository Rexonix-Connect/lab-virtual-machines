<#
    .NOTES
    ===========================================================================
        Created by:    Jakub Travnik <jakub.travnik@gmail.com>
        Organization:  Rexonix
    ===========================================================================
    .DESCRIPTION
        These are functions for taking screenshots from VMs and processing them with Azure Vision OCR.
        The functions are used to search for text on the VM screen and to expect text on the VM screen.
#>

Function Get-VMScreenshot {
    # Take screenshot from VM and save it to local machine
    Param (
        [Parameter(Mandatory=$true)][string]$vmName,
        [Parameter(Mandatory=$true)][string]$dcName,
        [Parameter(Mandatory=$false)][string]$fileName=$vmName + "_" + (Get-Date -Format "yyyy-MM-dd_hh-mm-ss") + ".png"
    )
    Write-Debug "Get-VMScreenshot | Searching for VM $vmName ..."
    $vm = Get-VM -Name $vmName
    if (!$vm) {
        Write-Error "Get-VMScreenshot | Unable to find VM $vmName"
        return
    }
    Write-Debug "Get-VMScreenshot | VM found."
    Write-Debug "Get-VMScreenshot | Creating screenshot for VM $vmName ..."
    (Get-Task -Id "Task-$((Get-VM -Name $vmName).ExtensionData.CreateScreenshot_Task().Value)" | Wait-Task) -Match "^\[([^]]+)\] (.*)$" | Out-Null
    Write-Debug "Get-VMScreenshot | Creating new PSDrive for datastore $fileDatastore ..."
    New-PSDrive -PSProvider VimDatastore -Name $Matches[1] -Root "vmstore:$dcName\$($Matches[1])" | Out-Null
    Write-Debug "Get-VMScreenshot | Copying screenshot to local machine ..."
    Copy-DatastoreItem "$($Matches[1]):\$($Matches[2])" $fileName
    Write-Debug "Get-VMScreenshot | Screenshot from VM $vmName saved to $fileName"
    Remove-Item "$($Matches[1]):\$($Matches[2])"
    Remove-PSDrive -Name $Matches[1]
    return $fileName.ToString()
}

Function Get-AzureVisionOCRResponse {
    # Send exisitng image to Azure and returns all text it contains
    Param (
        [Parameter(Mandatory=$true)][string]$fileName,
        [Parameter(Mandatory=$true)][string]$subscriptionKey,
        [Parameter(Mandatory=$true)][string]$endpoint,
        [Parameter(Mandatory=$false)][bool]$deleteFile=$true
    )
    Write-Debug "Get-AzureVisionOCRResponse | Sending screenshot $fileName to Azure Vision OCR ..."
    $curlResult = curl --silent `
                       -H "Ocp-Apim-Subscription-Key: $subscriptionKey" `
                       -H "Content-Type: application/octet-stream" `
                       "$endpoint/computervision/imageanalysis:analyze?features=caption,read&model-version=latest&language=en&api-version=2024-02-01" `
                       --data-binary "@$fileName"
    Write-Debug "Get-AzureVisionOCRResponse | Response from Azure Vision OCR received."
    $textOutput = (($curlResult | ConvertFrom-Json).readResult.blocks.lines | ForEach-Object { $_.text }) -join "`n"
    Write-Debug "Get-AzureVisionOCRResponse | Screenshot Text:"
    Write-Debug "Get-AzureVisionOCRResponse | =============================================================================================="
    Write-Debug $($textOutput -replace "(?m)^", "DEBUG: Get-AzureVisionOCRResponse | " -replace "^DEBUG: ", "" )
    Write-Debug "Get-AzureVisionOCRResponse | =============================================================================================="
    If ($deleteFile) {
        Write-Debug "Get-AzureVisionOCRResponse | Deleting screenshot ..."
        Remove-Item $fileName
    }
    Return $textOutput
}

Function GetTextFromVM {
    # Take screenshot from VM and get text it contains
    Param (
        [Parameter(Mandatory=$true)][string]$vmName,
        [Parameter(Mandatory=$true)][string]$dcName,
        [Parameter(Mandatory=$true)][string]$subscriptionKey,
        [Parameter(Mandatory=$true)][string]$endpoint
    )
    Write-Debug "GetTextFromVM | Getting text from VM $vmName ..."
    $fileName = Get-VMScreenshot -vmName $vmName -dcName $dcName
    $ocrText = Get-AzureVisionOCRResponse -fileName "$((Get-Location).Path)/$fileName" -subscriptionKey $subscriptionKey -endpoint $endpoint
    Write-Debug "GetTextFromVM | Text received."
    Return $ocrText
}

Function SearchTextOnVMScreen {
    # Search for text on VM screen
    Param (
        [Parameter(Mandatory=$true)][string]$searchText,
        [Parameter(Mandatory=$true)][string]$vmName,
        [Parameter(Mandatory=$true)][string]$dcName,
        [Parameter(Mandatory=$true)][string]$subscriptionKey,
        [Parameter(Mandatory=$true)][string]$endpoint,
        [Parameter(Mandatory=$false)][bool]$multiline=$false
    )
    Write-Debug "SearchTextOnVMScreen | Searching text '$searchText' on screen of '$vmName' VM ..."
    $ocrText = GetTextFromVM -vmName $vmName -dcName $dcName -subscriptionKey $subscriptionKey -endpoint $endpoint
    
    If ($multiline) { $searchText = "(?s)$searchText" }

    If ($ocrText -Match "$searchText") {
        Write-Debug "SearchTextOnVMScreen | Text found."
        Return $true
    } Else {
        Write-Debug "SearchTextOnVMScreen | Text not found."
        Return $false
    }
}

Function ExpectTextOnVMScreen {
    # Expect text on VM screen
    Param (
        [Parameter(Mandatory=$true)][string]$vmName,
        [Parameter(Mandatory=$true)][string]$dcName,
        [Parameter(Mandatory=$true)][string]$expectedText,
        [Parameter(Mandatory=$true)][string]$subscriptionKey,
        [Parameter(Mandatory=$true)][string]$endpoint,
        [Parameter(Mandatory=$false)][bool]$multiline=$false,
        [Parameter(Mandatory=$false)][int]$maxAttempts=5
    )
    Write-Debug "ExpectTextOnVMScreen | Expecting text '$expectedText' from VM $vmName ..."
    $attempt = 0
    $wasFound = $false
    While ($true -And $attempt -lt $maxAttempts) {
        $attempt++
        $textFound = SearchTextOnVMScreen -searchText $expectedText -vmName $vmName -dcName $dcName -subscriptionKey $subscriptionKey -endpoint $endpoint -multiline $multiline
        If ($textFound) {
            Write-Debug "ExpectTextOnVMScreen | Text found."
            $wasFound = $true
            Break
        } Else {
            Write-Debug "ExpectTextOnVMScreen | Text not found. Trying again ..."
        }
    }
    If (!$wasFound) {
        Write-Debug "ExpectTextOnVMScreen | Text '$expectedText' not found after $maxAttempts attempts."
    }
    Return $wasFound
}

Export-ModuleMember -Function Get-VMScreenshot, Get-AzureVisionOCRResponse, GetTextFromVM, SearchTextOnVMScreen, ExpectTextOnVMScreen
