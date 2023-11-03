# This script uses MGGraph module to check Microsoft 365 Groups and membership for groups that are linked to SharePoint Sites
Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All","Group.ReadWrite.All","GroupMember.Read.All"
Connect-SPOService -url https://your-domain-admin.sharepoint.com
$userEmail = "xyz@emaildomain.com"

# Get a list of all SharePoint sites
$sites = Get-SPOSite -Limit All
$total = $sites.URL
# Get-SPOSite -Template "GROUP#0" -IncludePersonalSite:$False -Limit All
$siteswithgroups = Get-SPOSite -Limit ALL -GroupIdDefined $true
$associatedgroups = $siteswithgroups.GroupID.Guid
$Groupmembershipforuser=@()
$Groupownershipforuser=@()
$sitetoaccessasmemberofgroup = @()

foreach ($id in $siteswithgroups) {
    $mem = Get-MgGroupMember -GroupId $id.GroupID.Guid
    $mem = $mem.id

        $groupowner = Get-MgGroupowner -GroupId $id.GroupID.Guid
    $groupowner = $groupowner.id



   # Write-Host "Will work on the group" (Get-MgGroup -GroupId $id.GroupID.Guid).DisplayName -ForegroundColor Yellow
    foreach ($a in $mem) {
        $userprincipalname = Get-MgUser -UserId $a -Property UserPrincipalName | Select-Object -ExpandProperty UserPrincipalName
        if ($userEmail -like $userprincipalname) {
            #Write-Host "User $userEmail is a member of the group" (Get-MgGroup -GroupId $id.GroupID.Guid).DisplayName -ForegroundColor Green

            $Groupmembershipforuser+=(Get-MgGroup -GroupId $id.GroupID.Guid).DisplayName

            $sitetoaccessasmemberofgroup += $id.Url 
        }
    }

    foreach ($b in $groupowner) {
        $userprincipalname = Get-MgUser -UserId $b -Property UserPrincipalName | Select-Object -ExpandProperty UserPrincipalName
        if ($userEmail -like $userprincipalname) {
           # Write-Host "User $userEmail is an owner of the group" (Get-MgGroup -GroupId $id.GroupID.Guid).DisplayName -ForegroundColor Green
            $sitetoaccessasmemberofgroup += $id.Url 
            $Groupownershipforuser+=(Get-MgGroup -GroupId $id.GroupID.Guid).DisplayName 


        }
    }


}

# $sitetoaccessasmemberofgroup

# Initialize an array to store sites with access
$siteswithaccess = @()
$Userisowneronsites = Get-SPOSite -Filter "Owner -like '$($userEmail)'"
$Userisowneronsites = $Userisowneronsites.URL

# $Sitestowork = Compare-Object $sitetoaccessasmemberofgroup $Userisowneronsites $total | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject

$Sitestowork = $total | Where-Object { $_ -notin $sitetoaccessasmemberofgroup -and $_ -notin $Userisowneronsites }
$Siteadminpresent = $null
$siteGroups = $null

# Iterate through the sites and check for user's access
foreach ($site in $Sitestowork) {
    $member = $null  # Initialize $member variable
    $siteGroups = $null
    
    # Check if the user is a site Admin
      try {
    # Attempt to get site admin information
    $Siteadminpresent = Get-SPOUser -Site $site -Limit ALL | Where-Object { $_.IsSiteAdmin -eq $True } | Where-Object { $_.loginname -like $userEmail }
    $siteGroups = Get-SPOSiteGroup -Site $site -ErrorAction SilentlyContinue


}
catch {
    # Handle the error gracefully (do nothing or log the error)
}

    # If the user is not a site Admin, check site groups for the user to be a member
    #$siteGroups = Get-SPOSiteGroup -Site $site -ErrorAction SilentlyContinue



    if (!$siteGroups) {  
        Write-Host "Our Admin account cannot access site $site to verify access" -ForegroundColor Red
    }
    else {
        foreach ($siteGroup in $siteGroups) {
            $users = $siteGroup.Users

            foreach ($user in $users) {
                if ($user -eq $userEmail) {

                if (!$($siteGroup.Roles))

                {
                Write-Host "User $userEmail has access to the site $site and is from the link $($siteGroup.Title)"

                }
                else
                {
                    Write-Host "User $userEmail has access to the site $site and has the role $($siteGroup.Roles)"from the title" $($siteGroup.Title)"
                    }


                    $member = 1  # User has access, set $member to 1
                }
            }
        }
    }

    # If $member is still null (user not found in site groups), add to siteswithaccess
    if ($member -or $Siteadminpresent -or ($sitetoaccessasmemberofgroup -contains $site)) {
        $siteswithaccess += $site
    }
}
Write-Host "User $userEmail is a member of the sharepoint related site groups" -ForegroundColor Yellow
$Groupmembershipforuser | ForEach-Object { Write-Host $_ -ForegroundColor Green } 

Write-Host "User $userEmail is an owner of the sharepoint related site groups" -ForegroundColor Yellow
$Groupownershipforuser | ForEach-Object { Write-Host $_ -ForegroundColor Green } 


# Output the list of sites with access
Write-host "User $userEmail" "has access to below sites" -ForegroundColor Yellow
$siteswithaccess




