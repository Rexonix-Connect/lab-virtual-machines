<#
    .NOTES
    ===========================================================================
        Created by:    Jakub Travnik <jakub.travnik@gmail.com>
        Organization:  Rexonix
    ===========================================================================
    .DESCRIPTION
        This script handles complete CML Personal deployment in a vSphere environment.
#>

. .\VMKeystrokes.ps1
. .\VMOCRUtils.ps1

Function Delete-Vm {
    Param (
        [Parameter(Mandatory=$true)][string]$vmName
    )
    $vm = Get-VM -Name $vmName
    If ($vm) {
        Write-Host "Deleting VM $vmName ..."
        Stop-VM -VM $vmName -Confirm:$false -ErrorAction Ignore
        Remove-VM -VM $vmName -DeletePermanently -Confirm:$false -ErrorAction Ignore
    }
}

Function Create-VmFromContentLibraryOvf {
    Param (
        [Parameter(Mandatory=$true)][string]$vmName,
        [Parameter(Mandatory=$true)][string]$clusterName,
        [Parameter(Mandatory=$true)][string]$contentLibraryName,
        [Parameter(Mandatory=$true)][string]$contentLibraryTemplateName,
        [Parameter(Mandatory=$true)][string]$datastoreName,
        [Parameter(Mandatory=$true)][string]$folderName
    )
    $contentLibrary = Get-ContentLibrary -Name $contentLibraryName
    $contentLibraryItem = Get-ContentLibraryItem -ContentLibrary $contentLibrary -Name $contentLibraryTemplateName
    $datastore = Get-Datastore -Name $datastoreName
    $vmHost = Get-VMHost -location $clusterName | Sort-Object $_.CPuUsageMhz -Descending | Select-Object -First 1
    New-VM -Name $vmName `
           -VMHost $vmHost `
           -ContentLibraryItem $contentLibraryItem `
           -Datastore $datastore `
           -Location $folderName `
           -DiskStorageFormat Thin `
           -Confirm:$false
}

Function WaitFor-SSH {
    Param (
        [Parameter(Mandatory=$true)][string]$ipv4Address,
        [Parameter(Mandatory=$true)][int]$port,
        [Parameter(Mandatory=$true)][int]$timeout
    )
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($timeout)
    while ($endTime -gt (Get-Date)) {
        if ($(ssh-keyscan -p $port -T 2 $ipv4Address)) {
            Write-Host "SSH is reachable on $ipv4Address."
            Break
        } else {
            Write-Host "Waiting for SSH to be reachable on $ipv4Address ..."
            Start-Sleep -Seconds 5
        }
    }
}

Function Attach-ContentLibraryIso {
    Param (
        [Parameter(Mandatory=$true)][string]$vmName,
        [Parameter(Mandatory=$true)][string]$contentLibraryName,
        [Parameter(Mandatory=$true)][string]$IsoName
    )
    $vm = Get-VM -Name $vmName
    if (!$vm) {
        Write-Error "Attach-ContentLibraryIso | Unable to find VM $vmName"
        return
    }
    if ($null -ne $($vm | Get-CDDrive)[0].IsoPath) {
        Write-Error "Attach-ContentLibraryIso | VM $vmName already has an Iso attached."
        return
    }
    $contentLibrary = Get-ContentLibrary -Name $contentLibraryName
    $Iso = Get-ContentLibraryItem -ContentLibrary $contentLibrary -Name $IsoName
    $IsoFullPath = (Get-ChildItem -Path vmstore:\$($contentLibrary.Datastore.Datacenter.Name)\$($contentLibrary.Datastore.Name)\contentlib-$($contentLibrary.Id)\$($Iso.Id)).DatastoreFullPath
    if ($vm.PowerState -eq "PoweredOn") {
        $vm | Get-CDDrive | Set-CDDrive -IsoPath $IsoFullPath -Connected $true -Confirm:$false    
    } else {
        $vm | Get-CDDrive | Set-CDDrive -IsoPath $IsoFullPath -StartConnected $true -Confirm:$false
    }
}

Function Dismount-CDDrives {
    Param (
        [Parameter(Mandatory=$true)][string]$vmName,
        [Parameter(Mandatory=$true)][string]$vcenter,
        [Parameter(Mandatory=$true)][string]$vcUser,
        [Parameter(Mandatory=$true)][string]$vcPassword
    )
    Write-Debug "Dismount-CDRom | Dismounting CD-ROM from VM $vmName ..."

    $cdQuestion = {
        Param( $vmName, $vcenter, $vcUser, $vcPassword )
        
        Connect-VIServer -Server $vcenter `
                         -User $vcUser `
                         -Password $vcPassword

        For ($pass = 0; $pass -lt 10; $pass++) {
            $question = Get-VM -Name $vmName | Get-VMQuestion -QuestionText "*locked the CD*"
            if ($question) {
                Set-VMQuestion -VMQuestion $question -Option button.yes -Confirm:$false
            }
            Start-Sleep 1
        }

        Disconnect-VIServer -Server $vcenter `
                            -Confirm:$false `
                            -ErrorAction SilentlyContinue
    }
   
    $job = Start-Job -Name Check-CDQuestion -ScriptBlock $cdQuestion -ArgumentList $vmName, $vcenter, $vcUser, $vcPassword
    Get-VM -Name $vmName | Get-CDDrive | Set-CDDrive -NoMedia -Confirm:$false -ErrorAction Stop

    Write-Debug "Dismount-CDRom | CD-ROMs dismounted."
}

Function RunCommandsAgainstVM {
    Param (
        [Parameter(Mandatory=$true)][string]$vmName,
        [Parameter(Mandatory=$true)][string]$dcName,
        [Parameter(Mandatory=$true)][array]$commands,
        [Parameter(Mandatory=$false)][string]$subscriptionKey="",
        [Parameter(Mandatory=$false)][string]$endpoint=""
    )

    Foreach ($command in $commands) {
        # Skip empty
        If ($command -Eq "") {
            Continue
        }

        # Handle conditional commands
        If ($command -Match "^{(IF LAST (SUCCEEDED|FAILED))} *(.*)$") {
            $requiredState = ($Matches[2] -eq "SUCCEEDED")
            If ($requiredState -eq $lastExpectState) {
                $command = $Matches[3]
            } Else {
                Write-Host "Skipping command '$($Matches[3])' due to last command state not matching required condition '$($Matches[1])'."
                Continue
            }
        }
    
        If ($command -Eq "{START-VM}") {
            If(-Not(Get-VM -Name $vmName)) {
                Write-Error "VM $vmName not found."
                Break
            }
            Write-Host "Starting VM $vmName ..."
            Start-VM -VM $vmName -RunAsync -Confirm:$false

        } ElseIf ($command -Eq "{RESTART-VM}") {
            If(-Not(Get-VM -Name $vmName)) {
                Write-Error "VM $vmName not found."
                Break
            }
            Write-Host "Restarting VM $vmName ..."
            Restart-VM -VM $vmName -RunAsync -Confirm:$false

        } ElseIf ($command -Eq "{STOP-VM}") {
            If(-Not(Get-VM -Name $vmName)) {
                Write-Error "VM $vmName not found."
                Break
            }
            Write-Host "Stopping VM $vmName ..."
            Stop-VM -VM $vmName -Confirm:$false

        } ElseIf ($command -Eq "{EXIT}") {
            Write-Host "Exiting script ..."
            Break

        } ElseIf ($command -Match "{SLEEP (\d+)}") {
            $sleepTime = $Matches[1]
            Write-Host "Sleeping for $sleepTime seconds ..."
            Start-Sleep -Seconds $sleepTime
    
        } ElseIf ($command -Eq "{SCREENSHOT}") {
            Write-Host "Getting screenshot from VM $vmName ..."
            Get-VMScreenshot -vmName $vmName -dcName $dcName | Out-Null
    
        } ElseIf ($command -Eq "{GET-TEXT}") {
            If ($subscriptionKey -eq "" -Or $endpoint -eq "") {
                Write-Error "Subscription key and endpoint are required for text recognition."
                Break
            }
            Write-Host "Getting screenshot from VM $vmName ..."
            GetTextFromVM -vmName $vmName `
                          -dcName $dcName `
                          -subscriptionKey $subscriptionKey `
                          -endpoint $endpoint
    
        } ElseIf ($command -Match "{EXPECT '(.*)'( ATTEMPTS (\d+))?}") {
            If ($subscriptionKey -eq "" -Or $endpoint -eq "") {
                Write-Error "Subscription key and endpoint are required for text recognition."
                Break
            }
            $expectedText = $Matches[1]
            If ($Matches[3]) {
                $maxAttempts = $Matches[3]
            } Else {
                $maxAttempts = 5
            }
            Write-Host "Expecting text: '$expectedText' with $maxAttempts attempts ..."
            $lastExpectState = ExpectTextOnVMScreen -vmName $vmName `
                                                    -dcName $dcName `
                                                    -expectedText $expectedText `
                                                    -subscriptionKey $subscriptionKey `
                                                    -endpoint $endpoint `
                                                    -multiline $true `
                                                    -maxAttempts $maxAttempts
            If (!$lastExpectState) {
                Write-Host "Text '$expectedText' not found after $maxAttempts attempts."
            }
    
        } Else {
            Write-Host "Sending command to VM: $command"
            Set-VMKeystrokes -VMName $vmName -StringInput $command
        }
    }
}
