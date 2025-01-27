<#
    .NOTES
    ===========================================================================
        Created by:    Jakub Travnik <jakub.travnik@gmail.com>
        Organization:  Rexonix
    ===========================================================================
    .DESCRIPTION
        These are functions for handling CML Personal deployment via API.
#>

Function Register-CML {
    Param (
        [Parameter(Mandatory=$true)][string]$fqdn,
        [Parameter(Mandatory=$true)][string]$cmlAdminUsername,
        [Parameter(Mandatory=$true)][string]$cmlAdminPassword,
        [Parameter(Mandatory=$true)][string]$cmlLicenseKey
    )
    $apiBaseUrl = "https://$fqdn/api/v0"
    $token = $(curl -k -X "POST" `
                    "$apiBaseUrl/authenticate" `
                    -H "accept: application/json" `
                    -H "Content-Type: application/json" `
                    -d "{`"username`":`"$cmlAdminUsername`",`"password`":`"$cmlAdminPassword`"}" `
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
        [Parameter(Mandatory=$true)][string]$cmlAdminUsername,
        [Parameter(Mandatory=$true)][string]$cmlAdminPassword
    )
    $apiBaseUrl = "https://$fqdn/api/v0"
    $token = $(curl -k -X "POST" `
                    "$apiBaseUrl/authenticate" `
                    -H "accept: application/json" `
                    -H "Content-Type: application/json" `
                    -d "{`"username`":`"$cmlAdminUsername`",`"password`":`"$cmlAdminPassword`"}" `
              ) | ConvertFrom-Json

    curl -k -X 'DELETE' `
         "$apiBaseUrl/licensing/deregistration" `
         -H "accept: application/json" `
         -H "Authorization: Bearer $token"
}

Function Create-LabInCml {
    Param (
        [Parameter(Mandatory=$true)][string]$fqdn,
        [Parameter(Mandatory=$true)][string]$cmlAdminUsername,
        [Parameter(Mandatory=$true)][string]$cmlAdminPassword,
        [Parameter(Mandatory=$true)][string]$labName,
        [Parameter(Mandatory=$true)][string]$labDescription,
        [Parameter(Mandatory=$true)][string]$labNotes
    )
    $token = $(curl -k -X "POST" `
                    "https://$fqdn/api/v0/authenticate" `
                    -H "accept: application/json" `
                    -H "Content-Type: application/json" `
                    -d "{`"username`":`"$cmlAdminUsername`",`"password`":`"$cmlAdminPassword`"}" `
              ) | ConvertFrom-Json
    
    $urlEncodedlabName = [System.Web.HttpUtility]::UrlEncode($labName)
    curl -k -X 'POST' `
         "https://$fqdn/api/v0/labs?title=$urlEncodedlabName" `
         -H "accept: application/json" `
         -H "Authorization: Bearer $token" `
         -H "Content-Type: application/json" `
         -d "{`"title`":`"$labName`",`"description`":`"$labDescription`",`"notes`":`"$labNotes`"}"
}
