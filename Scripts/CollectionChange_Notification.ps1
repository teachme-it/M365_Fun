$SiteCode = "PRI"
$CollectionID = "PRI00169"
$OutputDir="C:\Temp"
$EmailFrom = "russ@russrimmerman.com"
$EmailTo = "russ@russrimmerman.com"
$SmtpServer = "smtp.office365.com"

#Get the current member count of the collection from WMI
$NewCollectionCount = (Get-WmiObject -Namespace Root\SMS\site_$SiteCode -Query "Select MemberCount from SMS_Collection Where CollectionID='$CollectionID'").MemberCount

#If the script hasn't ever been run before, the file won't exist, so don't try to read it.
If (Test-Path "$OutputDir\$($CollectionID)-Count.txt") {$OldCollectionCount = Get-Content ("$OutputDir\$($CollectionID)-Count.txt")}

#Get the current members of the collection from WMI
$NewCollectionMembers = (Get-WmiObject -Namespace Root\SMS\Site_$SiteCode -Query "Select Name from SMS_FullCollectionMembership Where CollectionID='$CollectionID'").Name

#Check to see if the file containing the collection members exists. If the script hasn't ever been run before, the file won't exist, so don't try to read it and don't do any comparisons.
If (Test-Path "$OutputDir\$($CollectionID)-Members.txt")

    #If it does, do the following:
    {
    #Get the previous members of the collection at last script run
    $OldCollectionMembers = Get-Content("$OutputDir\$($CollectionID)-Members.txt")

    #Compare the difference between the previous run and this run
    $MemberChanges = Compare-Object -ReferenceObject $OldCollectionMembers -DifferenceObject $NewCollectionMembers

    #Servers that have been removed will have a => SideIndicator
    $ServersRemoved = ($MemberChanges | ?{$_.SideIndicator -eq '<='}).InputObject

    #Servers that have been added will have a <= SideIndicator
    $ServersAdded = ($MemberChanges | ?{$_.SideIndicator -eq '=>'}).InputObject
    }

    #If the script hasn't ever been run before, create the output file containing the current collection members & count for use on the next execution.
    Else
        {
        $NewCollectionMembers | Out-File "$OutputDir\$($CollectionID)-Members.txt"
        $NewCollectionCount | Out-File "$OutputDir\$($CollectionID)-Count.txt"
        }

#Check to see if there are any members in either variable (any servers were added or removed since last run) 
If (($ServersRemoved) -or ($ServersAdded))

    #If there are members in either one, do the following:
    {

    #Create a hashtable of the delta lists so we have a nicely formatted two column list to be used for the e-mail body
    $DeltaList = [pscustomobject] 
                                                         @{
                                                          "Servers Added" = $ServersAdded
                                                          "Servers Removed" = $ServersRemoved
                                                          }

$List = [PSCustomObject]$DeltaList | ConvertTo-Html -Fragment


$Header = @"
<style>
Table {border-width; 1px; border-style: solid; border-color: black; border-collapse:collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

#Create a link for the e-mail recipients to click
#$LinkText = '<br>Click <a href="http://srvusascc07/reports/powerbi/Microsoft%20SQL%20Servers%20Deployed">here</a> to view the current list of servers.<br><br>'

#Decode any HTML encoding since we're using ConvertTo-Html for the whole body
Add-Type -AssemblyName System.Web
[System.Web.HttpUtility]::HtmlDecode($LinkText)

#Create an image and text for the bottom of the e-mail
#$PostHtml = '<p><h2><img src="https://endpointsystems.blob.core.windows.net/files/endpoint-logo-only.jpg" align="middle" height="50" width="50">Endpoint Systems</p></h2>'

#Build the body of the e-mail using the hashtable, and convert it to html including the $LinkText at the top and $PostHtml at the bottom
$Body=[PSCustomObject]$List | Select "Servers Added","Servers Removed" | ConvertTo-Html -Property "Servers Added","Servers Removed" -Head $Header | Out-String

#Send an e-mail with the old and new server list
Send-MailMessage -SmtpServer $SmtpServer -BodyAsHtml -From $EmailFrom -To $EmailTo -Subject "The SQL server count has changed. Old count: $($OldCollectionCount), New count: $($NewCollectionCount)" -Body $Body

#Write it to the console also in case we're manually running it so we can tell if its working.  This can be commented out if desired - it wont affect functionality.
Write-Host "The SQL Server Count has changed.  Old Count: $OldCollectionCount, New Count: $NewCollectionCount"

#Write the new count of the collection to a file so we can reference it on the next run
$NewCollectionCount | Out-File "$OutputDir\$($CollectionID)-Count.txt"

#Write the new members of the collection to a file so we can reference it on the next run
$NewCollectionMembers | Out-File "$OutputDir\$($CollectionID)-Members.txt"
}

#The End 
