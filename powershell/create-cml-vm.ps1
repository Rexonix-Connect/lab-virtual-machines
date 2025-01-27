<#
    .NOTES
    ===========================================================================
        Created by:    Jakub Travnik <jakub.travnik@gmail.com>
        Organization:  Rexonix
    ===========================================================================
    .DESCRIPTION
        This script handles complete CML Personal deployment in a vSphere environment.
#>

. ".\utils\VMKeystrokes.ps1"
. ".\utils\VMOCRUtils.ps1"
. ".\utils\VMUtils.ps1"

Function Register-CML {
    Param (
        [Parameter(Mandatory=$true)][string]$fqdn,
        [Parameter(Mandatory=$true)][string]$cmlAdminPassword,
        [Parameter(Mandatory=$true)][string]$cmlLicenseKey
    )
    $apiBaseUrl = "https://$fqdn/api/v0"
    $token = $(curl -k -X "POST" `
                    "$apiBaseUrl/authenticate" `
                    -H "accept: application/json" `
                    -H "Content-Type: application/json" `
                    -d "{`"username`":`"admin`",`"password`":`"$cmlAdminPassword`"}" `
              ) | ConvertFrom-Json

    curl -k -X 'PUT' `
         "$apiBaseUrl/licensing/product_license" `
         -H "accept: application/json" `
         -H "Authorization: Bearer $token" `
         -H "Content-Type: application/json" `
         -d '"CML_Personal"'

    curl -k -X 'POST' `
         "$apiBaseUrl/licensing/registration" `
         -H "accept: application/json" `
         -H "Authorization: Bearer $token" `
         -H "Content-Type: application/json" `
         -d "{`"token`":`"$cmlLicenseKey`",`"reregister`":false}"

    curl -k -X 'GET' `
         "$apiBaseUrl/licensing" `
         -H "accept: application/json" `
         -H "Authorization: Bearer $token"
}

Function Deregister-CML {
    Param (
        [Parameter(Mandatory=$true)][string]$fqdn,
        [Parameter(Mandatory=$true)][string]$cmlAdminPassword
    )
    $apiBaseUrl = "https://$fqdn/api/v0"
    $token = $(curl -k -X "POST" `
                    "$apiBaseUrl/authenticate" `
                    -H "accept: application/json" `
                    -H "Content-Type: application/json" `
                    -d "{`"username`":`"admin`",`"password`":`"$cmlAdminPassword`"}" `
              ) | ConvertFrom-Json

    curl -k -X 'DELETE' `
         "$apiBaseUrl/licensing/deregistration" `
         -H "accept: application/json" `
         -H "Authorization: Bearer $token"
}

Function Create-LabInCml {
    Param (
        [Parameter(Mandatory=$true)][string]$fqdn,
        [Parameter(Mandatory=$true)][string]$cmlAdminPassword,
        [Parameter(Mandatory=$true)][string]$labName,
        [Parameter(Mandatory=$true)][string]$labDescription,
        [Parameter(Mandatory=$true)][string]$labNotes
    )
    $token = $(curl -k -X "POST" `
                    "https://$fqdn/api/v0/authenticate" `
                    -H "accept: application/json" `
                    -H "Content-Type: application/json" `
                    -d "{`"username`":`"admin`",`"password`":`"$cmlAdminPassword`"}" `
              ) | ConvertFrom-Json
    
    $urlEncodedlabName = [System.Web.HttpUtility]::UrlEncode($labName)
    curl -k -X 'POST' `
         "https://$fqdn/api/v0/labs?title=$urlEncodedlabName" `
         -H "accept: application/json" `
         -H "Authorization: Bearer $token" `
         -H "Content-Type: application/json" `
         -d "{`"title`":`"$labName`",`"description`":`"$labDescription`",`"notes`":`"$labNotes`"}"
}

########################################################################################################
########################################################################################################

# CML config
$cmlSshPort = 1122
$cmlDeploymentMode = "standalone"
$cmlSysadminPassword = "B0ardsWak3s!"
$cmlAdminPassword = "B0ardsWak3s!"
$cmlIsoImages = @("refplat-20240225-fcs", "refplat-20240322-supplemental")


# commands to send to VM sequentially
$commands = @(
    "{START-VM}",
    "{SLEEP 20}",
    "{EXPECT 'Continue'}",
    "{enter}"
    "{EXPECT 'Accept EULA'}",
    "a{enter}",
    "{EXPECT 'Welcome.*Continue'}",
    "c{enter}",
    "{EXPECT 'Brief Help.*Continue'}",
    "c{enter}",
    #
    "{EXPECT 'The setup will proceed with standalone.*Continue' ATTEMPTS 2}", # Single network adapter
    "{IF LAST SUCCEEDED} c{enter}",
    "{EXPECT 'Is this host a regular standalone instance.*Standalone' ATTEMPTS 2}", # Multiple network adapters
    "{IF LAST SUCCEEDED} $( $cmlDeploymentMode -eq 'standalone' ? 's' : 'c' ){enter}",
    #
    "{EXPECT 'Enter this system's unique hostname.*cml-controller.*Continue'}",
    "{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}{backspace}",
    "cml{enter}",
    #
    "{EXPECT 'Please attach the reference platform image.*Continue' ATTEMPTS 2}",
    "{IF LAST SUCCEEDED} {EXIT}", # missing Iso
    #
    "{EXPECT 'Define the username and the password.*sysadmin.*Continue'}",
    "{down}$cmlSysadminPassword{down}$cmlSysadminPassword{enter}",
    "{EXPECT 'Define the username and the password.*admi(n|r).*Continue'}",
    "{IF LAST FAILED} {EXIT}",
    "{down}$cmlAdminPassword{down}$cmlAdminPassword{enter}",
    #
    "{EXPECT 'There are multiple active ethernet network interfaces.*Continue'}",
    "{enter}",
    "{EXPECT 'Optionally define a static IPv4 address.*Continue'}",
    "{down}{space}{enter}"
    "{EXPECT 'Specify a static IPv4 address.*Continue'}",
    "$cmlIPv4Address{down}",
    "$cmlIPv4Netmask{down}",
    "$cmlIPv4Gateway{down}",
    "$cmlIPv4DNS{down}",
    "home.arpa{enter}",
    #
    "{EXPECT 'Please confirm your configuration.*Confirm'}",
    "{enter}",
    #
    "{EXPECT 'Reference Platform images will.*Continue'}",
    "{enter}",
    "{SLEEP 600}",
    "{EXPECT 'Ubuntu.*Access the CML UI.*Web console.*login'}",
    #
    "sysadmin{enter}",
    "{EXPECT 'Password'}",
    "$cmlSysadminPassword{enter}",
    "{EXPECT 'admin@cml'}",
    "sudo systemctl start ssh.service{enter}"
    "{EXPECT '[sudo].*password'}",
    "$cmlSysadminPassword{enter}",
    #
    "{GET-TEXT}"
)

RunCommandsAgainstVM -vmName $vmName `
                     -dcName $dcName `
                     -commands $commands `
                     -subscriptionKey $subscriptionKey `
                     -endpoint $endpoint

WaitFor-SSH -ipv4Address $cmlIPv4Address -port $cmlSshPort -timeout 300

# attach Iso 2
Dismount-CDDrives -vmName $vmName -vcenter $vcenter -vcUser $vcUser -vcPassword $vcPassword
Attach-ContentLibraryIso -vmName $vmName -contentLibraryName $contentLibraryName -IsoName $cmlIsoImages[1]

@"
printf "=============================================\nStarting script...\n"
# get sudo
echo "$cmlSysadminPassword" | sudo -S uptime
#
systemctl list-units --type=service --all virl*
printf "=============================================\nStopping CML services..."
sudo systemctl stop virl2.target
sleep 10
printf "   done\n"
systemctl list-units --type=service --all virl*
#
cdrom_path=`$(readlink -f /dev/disk/by-label/REFPLAT)
printf "=============================================\nMounting `$cdrom_path to /tmp/refplat_iso..."
sudo mount `$cdrom_path /tmp/refplat_iso/
printf "   done\n"
#
printf "=============================================\nCopying content of /tmp/refplat_iso to /var/lib/libvirt/images (this may take a while)...\n"
sudo rsync -avv /tmp/refplat_iso/ /var/lib/libvirt/images/
printf "   done\n"
#
printf "=============================================\nSetting permissions..."
sudo chown -R libvirt-qemu:virl2 /var/lib/libvirt/images/*
#
sudo chmod 464 /var/lib/libvirt/images/node-definitions/*
#
sudo chmod -R 464 /var/lib/libvirt/images/virl-base-images/* # all files first
sudo chmod 575 /var/lib/libvirt/images/virl-base-images/* # folders only
printf "   done\n"
ls -l /var/lib/libvirt/images/virl-base-images/
ls -l /var/lib/libvirt/images/node-definitions/
#
printf "=============================================\nUnmounting /tmp/refplat_iso..."
sudo umount /tmp/refplat_iso/
printf "   done\n"
#
printf "=============================================\nRestarting controller to reload images into CML2 controller..."
sudo systemctl start virl2.target
sleep 10
printf "   done\n"
systemctl list-units --type=service --all virl*
printf "=============================================\nExiting..."
"@ | sshpass -p $cmlSysadminPassword ssh sysadmin@$cmlIPv4Address -p 1122 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

Dismount-CDDrives -vmName $vmName -vcenter $vcenter -vcUser $vcUser -vcPassword $vcPassword

Disconnect-VIServer -Server $vcenter `
                    -Confirm:$false `
                    -ErrorAction SilentlyContinue

$licenseKey = "MzU0ZjY1ZjgtNjc5My00NmZiLTlhMzktNDM1YzYzNmE5ZTYwLTE3NDYxMTgz%0AODYxNDd8cEpmek42NXZEZEdOaG9FZXJRTXM2bVREZDh0U2hkN1VVRDc4N2ZJ%0AbzlJRT0%3D%0A"
Register-CML -fqdn $vmName -cmlAdminPassword $cmlAdminPassword -cmlLicenseKey $licenseKey
