﻿<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>


$clientInfo = ''
$clientID = '5386e89b-03c3-44a0-b728-5d8072f3f8c2'
$secretPass = 'JdT_15xo35-v3vpQx-2HX5B-XxOmrY95-r'
$tenant = '267b49a9-9593-4a3f-8ef7-4e6e044b1e86'

# MUFG Tenant Graph App
#$clientID = 'f01c2f72-5c93-41b4-9258-ccbf6a1ac101'
#$secretPass = 'ziD_.7SWJjejaVw0TnG~MglFm0M2PJxTS_'
#$tenant = '5063e2f5-e7fd-408d-92bc-e69455161a97'

#Required credentials - Get the client_id and client_secret from the app when creating it in Azure AD
$client_id = $clientID #App ID
$client_secret = $secretPass #API Access Key Password

#tenant_id can be read from the azure portal of your tenant (check the properties blade on your azure active directory)
$tenant_id = $tenant #Directory ID

<####################################################

param
(
[parameter(Mandatory=$false)]
$DeviceName,
[parameter(Mandatory=$false)]
$UserPrincipalName

)

####################################################>

function Get-AuthToken {

<#
.SYNOPSIS
This function is used to authenticate with the Graph API REST interface
.DESCRIPTION
The function authenticate with the Graph API Interface with the tenant name
.EXAMPLE
Get-AuthToken
Authenticates you with the Graph API interface
.NOTES
NAME: Get-AuthToken
#>

    param
    (
        [Parameter(Mandatory=$true)]
        $TenantID,
        [Parameter(Mandatory=$true)]
        $ClientID,
        [Parameter(Mandatory=$true)]
        $ClientSecret
    )
               
    try{
        # Define parameters for Microsoft Graph access token retrieval
        $resource = "https://graph.microsoft.com"
        $authority = "https://login.microsoftonline.com/$TenantID"
        $tokenEndpointUri = "$authority/oauth2/token"
               
        # Get the access token using grant type client_credentials for Application Permissions
        $content = "grant_type=client_credentials&client_id=$ClientID&client_secret=$ClientSecret&resource=$resource"
        $response = Invoke-RestMethod -Uri $tokenEndpointUri -Body $content -Method Post -UseBasicParsing -Verbose:$false

        Write-Host "Got new Access Token!" -ForegroundColor Green
        Write-Host

        # If the accesstoken is valid then create the authentication header
        if($response.access_token){
               
            # Creating header for Authorization token
               
            $authHeader = @{
                'Content-Type'='application/json'
                'Authorization'="Bearer " + $response.access_token
                'ExpiresOn'=$response.expires_on
            }
               
            return $authHeader
               
        }
        else{    
            Write-Error "Authorization Access Token is null, check that the client_id and client_secret is correct..."
            break    
        }
    }
    catch{    
        FatalWebError -Exeption $_.Exception -Function "Get-AuthToken"   
    }

}

####################################################

Function Get-ValidToken {

<#
    .SYNOPSIS
    This function is used to identify a possible existing Auth Token, and renew it using Get-AuthToken, if it's expired
    .DESCRIPTION
    Retreives any existing Auth Token in the session, and checks for expiration. If Expired, it will run the Get-AuthToken Fucntion to retreive a new valid Auth Token.
    .EXAMPLE
    Get-ValidToken
    Authenticates you with the Graph API interface by reusing a valid token if available - else a new one is requested using Get-AuthToken
    .NOTES
    NAME: Get-ValidToken
#>

    #Fixing client_secret illegal char (+), which do't go well with web requests
    $client_secret = $($client_secret).Replace("+","%2B")
               
    # Checking if authToken exists before running authentication
    if($global:authToken){
               
        # Get current time in (UTC) UNIX format (and ditch the milliseconds)
        $CurrentTimeUnix = $((get-date ([DateTime]::UtcNow) -UFormat +%s)).split((Get-Culture).NumberFormat.NumberDecimalSeparator)[0]
                              
        # If the authToken exists checking when it expires (converted to minutes for readability in output)
        $TokenExpires = [MATH]::floor(([int]$authToken.ExpiresOn - [int]$CurrentTimeUnix) / 60)
               
        if($TokenExpires -le 0){    
            Write-Host "Authentication Token expired" $TokenExpires "minutes ago! - Requesting new one..." -ForegroundColor Green
            $global:authToken = Get-AuthToken -TenantID $tenant_id -ClientID $client_id -ClientSecret $client_secret    
        }
        else{
            Write-Host "Using valid Authentication Token that expires in" $TokenExpires "minutes..." -ForegroundColor Green
            Write-Host
        }
    }    
    # Authentication doesn't exist, calling Get-AuthToken function    
    else {       
        # Getting the authorization token
        $global:authToken = Get-AuthToken -TenantID $tenant_id -ClientID $client_id -ClientSecret $client_secret    
    }    
}

####################################################

Function Get-AADUser(){

<#
.SYNOPSIS
This function is used to get AAD Users from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any users registered with AAD
.EXAMPLE
Get-AADUser
Returns all users registered with Azure AD
.EXAMPLE
Get-AADUser -userPrincipleName user@domain.com
Returns specific user by UserPrincipalName registered with Azure AD
.NOTES
NAME: Get-AADUser
#>

[cmdletbinding()]

param
(
    $userPrincipalName,
    $Property
)

# Defining Variables
$graphApiVersion = "beta"
$User_resource = "users"
    
    try {
        
        if($userPrincipalName -eq "" -or $userPrincipalName -eq $null){
        
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        
        }

        else {
            
            if($Property -eq "" -or $Property -eq $null){

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName"
            Write-Verbose $uri
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get

            }

            else {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName/$Property"
            Write-Verbose $uri
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

            }

        }
    
    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Output ("Response content:`n$responseBody")
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    break

    }

}

####################################################

Function Get-AADGroup(){

<#
.SYNOPSIS
This function is used to get AAD Groups from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Groups registered with AAD
.EXAMPLE
Get-AADGroup
Returns all users registered with Azure AD
.NOTES
NAME: Get-AADGroup
#>

[cmdletbinding()]

param
(
    $GroupName,
    $id,
    [switch]$Members
)

# Defining Variables
$graphApiVersion = "beta"
$Group_resource = "groups"
    
  #  try {

        if($id -and !$Members){

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=id eq '$id'"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

        }
        
        elseif(($GroupName -eq "" -or $GroupName -eq $null) -and !$Members){
        
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        
        }

        else {
            
            if(!$Members){

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            
            }
            
            elseif($Members){
            
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
            $Group = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            
                if($Group){

                $GID = $Group.id

                $Group.displayName
                write-host

                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)/$GID/Members"
                (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

                }

            }
        
        }
    <#
    } catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }#>

}

####################################################

function Get-Win10IntuneManagedDevice {

<#
.SYNOPSIS
This gets information on Intune managed devices
.DESCRIPTION
This gets information on Intune managed devices
.EXAMPLE
Get-Win10IntuneManagedDevice
.NOTES
NAME: Get-Win10IntuneManagedDevice
#>

[cmdletbinding()]

param
(
[parameter(Mandatory=$false)]
[ValidateNotNullOrEmpty()]
[string]$deviceName
)
    
    $graphApiVersion = "beta"

    try {

        if($deviceName){

            $Resource = "deviceManagement/managedDevices?`$filter=deviceName eq '$deviceName'"
               $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" 

            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value

        }

        else {

            $Resource = "deviceManagement/managedDevices?`$filter=(((deviceType%20eq%20%27desktop%27)%20or%20(deviceType%20eq%20%27windowsRT%27)%20or%20(deviceType%20eq%20%27winEmbedded%27)%20or%20(deviceType%20eq%20%27surfaceHub%27)))"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

            $DevicesResponse = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get

            $Devices = $DevicesResponse.value

            $DevicesNextLink = $DevicesResponse."@odata.nextLink"

            while ($DevicesNextLink -ne $null){

                $DevicesResponse = Invoke-RestMethod -Uri $DevicesNextLink -Headers $authToken -Method Get
                $DevicesNextLink = $DevicesResponse."@odata.nextLink"
                $Devices += $DevicesResponse.value
            }

            return $Devices

        }

    } catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Output ("Response content:`n$responseBody")
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        throw "Get-IntuneManagedDevices error"
    } 

}

####################################################

function Get-IntuneDevicePrimaryUser {

<#
.SYNOPSIS
This lists the Intune device primary user
.DESCRIPTION
This lists the Intune device primary user
.EXAMPLE
Get-IntuneDevicePrimaryUser
.NOTES
NAME: Get-IntuneDevicePrimaryUser
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    [string] $deviceId
)
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
       $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"

    try {
        
        $primaryUser = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get

        return $primaryUser.value."id"
        
       } catch {
             $ex = $_.Exception
             $errorResponse = $ex.Response.GetResponseStream()
             $reader = New-Object System.IO.StreamReader($errorResponse)
             $reader.BaseStream.Position = 0
             $reader.DiscardBufferedData()
             $responseBody = $reader.ReadToEnd();
             Write-Output ("Response content:`n$responseBody")
             Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
             throw "Get-IntuneDevicePrimaryUser error"
       }
}

####################################################

Function Get-DeviceConfigurationPolicy(){

<#
.SYNOPSIS
This function is used to get device configuration policies from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any device configuration policies
.EXAMPLE
Get-DeviceConfigurationPolicy
Returns any device configuration policies configured in Intune
.NOTES
NAME: Get-DeviceConfigurationPolicy
#>

[cmdletbinding()]

param
(
    $name
)

$graphApiVersion = "Beta"
$DCP_resource = "deviceManagement/deviceConfigurations"

    try {

        if($Name){

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") }

        }

        else {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

        }

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

####################################################

Function Get-DeviceConfigurationPolicyAssignment(){

<#
.SYNOPSIS
This function is used to get device configuration policy assignment from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets a device configuration policy assignment
.EXAMPLE
Get-DeviceConfigurationPolicyAssignment $id guid
Returns any device configuration policy assignment configured in Intune
.NOTES
NAME: Get-DeviceConfigurationPolicyAssignment
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true,HelpMessage="Enter id (guid) for the Device Configuration Policy you want to check assignment")]
    $id
)

$graphApiVersion = "Beta"
$DCP_resource = "deviceManagement/deviceConfigurations"

    try {

    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id/groupAssignments"
    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

####################################################

#region Authentication

# Checking if authToken exists before running authentication
if($global:authToken){

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

    if($TokenExpires -le 0){

        Write-Output ("Authentication Token expired" + $TokenExpires + "minutes ago")

        #Calling Microsoft to see if they will give us access with the parameters defined in the config section of this script.
        Get-ValidToken

        $global:authToken = Get-AuthToken -TenantID $tenant_id -ClientID $client_id -ClientSecret $client_secret
    }
}

# Authentication doesn't exist, calling Get-AuthToken function

else {

    #Calling Microsoft to see if they will give us access with the parameters defined in the config section of this script.
    Get-ValidToken

    # Getting the authorization token
    $global:authToken = Get-AuthToken -TenantID $tenant_id -ClientID $client_id -ClientSecret $client_secret
}

#endregion

####################################################


# Get all device config policies with name "Ring" in it
# Grabs all servicing ring device config policies
$ServicingRing = "Ring"
$DCPs = Get-DeviceConfigurationPolicy -name $ServicingRing

$outputArray = @()

write-host
write-host "Getting Windows 10 Update Ring policy assignments for servicing rings with names like: "" $ServicingRing """ -f Yellow
write-host

foreach($DCP in $DCPs){

    write-host "Windows 10 Update Ring policy name:"$DCP.displayName -f Yellow
    write-host

    $id = $DCP.id
    $DCPA = Get-DeviceConfigurationPolicyAssignment -id $id

    
    if($DCPA){
        
        foreach($group in $DCPA){

            $groupID = Get-AADGroup -id $group.targetGroupId
            $groupMembers = (Get-AADGroup -id $groupID.id -Members -GroupName $groupID.displayName).displayName
            $groupMemberIDs = (Get-AADGroup -id $groupID.id -Members -GroupName $groupID.displayName).deviceId

            Write-Host "Assigned group Name : " $groupID.displayName -f Cyan
                
            foreach($member in $groupMembers){ 
                
                $device = Get-Win10IntuneManagedDevice -deviceName $member
                $primaryUser = Get-IntuneDevicePrimaryUser -deviceId $device.id
                $userName = Get-AADUser -userPrincipalName $primaryUser

                $outputArray += New-Object PSObject -Property @{
                    DeviceName = $member
                    OSVersion = $device.osVersion
                    Compliance = $device.complianceState
                    LastSync = $device.lastSyncDateTime
                    EnrollmentDate = $device.enrolledDateTime
                    UserName = $userName.displayName
                    JobTitle = $userName.jobTitle
                    Department = $userName.department
                    Manufacturer = $device.manufacturer
                    Model = $device.model
                    GroupName = $groupID.displayName
                    ServicingRingName = $DCP.displayName

                }

                $output = $member + " : " + $userName.displayName
                Write-Output $output
            }
        }

    }
    else {
        Write-Host "No assignments found."
    }

}

$multiple_output = $outputArray | Out-GridView -Title "Servicing Ring devices"
Write-Host