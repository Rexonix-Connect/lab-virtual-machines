<#
    .NOTES
    ===========================================================================
        Created by:    Jakub Travnik <jakub.travnik@gmail.com>
        Organization:  Rexonix
    ===========================================================================
    .DESCRIPTION
        This script handles complete CML Personal deployment in a vSphere environment.
#>

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

