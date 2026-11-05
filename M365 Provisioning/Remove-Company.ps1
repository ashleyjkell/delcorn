<#
.SYNOPSIS
  Removes the Delcorn fictional training sites from a SharePoint tenant.

.DESCRIPTION
  Deletes only the sites this pack created (/sites/<SitePrefix>-<alias>), so other fictional companies in the
  same tenant are untouched. Deleted sites go to the tenant recycle bin (restorable for 93 days) unless -Purge.

.EXAMPLE
  ./Remove-Company.ps1 -TenantName contoso -ClientId <id>
  ./Remove-Company.ps1 -TenantName contoso -ClientId <id> -Purge -RemoveGroup "Delcorn Learners"
#>
param(
    [Parameter(Mandatory)] [string]$TenantName,
    [Parameter(Mandatory)] [string]$ClientId,
    [string]$SitePrefix = 'DLC',
    [switch]$Purge,
    [string]$RemoveGroup,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$BaseUrl  = "https://$TenantName.sharepoint.com"
$AdminUrl = "https://$TenantName-admin.sharepoint.com"

$Sites = @(
    @{Title='Delcorn Hub'; Alias='Hub'; IsHub=$true}
    @{Title='Executive & Board'; Alias='Exec'; IsHub=$false}
    @{Title='Learning Delivery'; Alias='Delivery'; IsHub=$false}
    @{Title='Curriculum & Academies'; Alias='Curriculum'; IsHub=$false}
    @{Title='Quality & Compliance'; Alias='Quality'; IsHub=$false}
    @{Title='Safeguarding & Learner Support'; Alias='Safeguarding'; IsHub=$false}
    @{Title='Employer Partnerships'; Alias='Partnerships'; IsHub=$false}
    @{Title='Finance & Funding'; Alias='Finance'; IsHub=$false}
    @{Title='People & Culture'; Alias='People'; IsHub=$false}
    @{Title='Learning Technology & IT'; Alias='Tech'; IsHub=$false}
)

function Site-Url($alias) { "$BaseUrl/sites/$SitePrefix-$alias" }

Write-Host "This will delete:" -ForegroundColor Yellow
$Sites | ForEach-Object { Write-Host "  $(Site-Url $_.Alias)" }
if (-not $Force) {
    $answer = Read-Host "Type the prefix '$SitePrefix' to confirm"
    if ($answer -ne $SitePrefix) { Write-Host "Cancelled."; return }
}

Connect-PnPOnline -Url $AdminUrl -Interactive -ClientId $ClientId
$hub = $Sites | Where-Object { $_.IsHub } | Select-Object -First 1
if ($hub) {
    try { Unregister-PnPHubSite -Site (Site-Url $hub.Alias) -ErrorAction Stop; Write-Host "Unregistered hub" }
    catch { Write-Host "Hub not registered: $($_.Exception.Message)" }
}
foreach ($s in $Sites) {
    $url = Site-Url $s.Alias
    if (-not (Get-PnPTenantSite -Identity $url -ErrorAction SilentlyContinue)) { Write-Host "Not found: $url"; continue }
    Remove-PnPTenantSite -Url $url -Force
    Write-Host "Deleted $url" -ForegroundColor Green
    if ($Purge) {
        # the deleted site can take a moment to reach the recycle bin
        for ($i = 0; $i -lt 12; $i++) {
            try { Remove-PnPTenantDeletedSite -Identity $url -Force -ErrorAction Stop; Write-Host "  purged"; break }
            catch { Start-Sleep -Seconds 10 }
        }
    }
}
if ($RemoveGroup) {
    try { Remove-PnPEntraIDGroup -Identity $RemoveGroup -ErrorAction Stop; Write-Host "Removed group $RemoveGroup" }
    catch { Write-Host "Could not remove group: $($_.Exception.Message)" -ForegroundColor Yellow }
}
Write-Host "Done." -ForegroundColor Cyan
