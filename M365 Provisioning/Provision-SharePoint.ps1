<#
.SYNOPSIS
  Provisions the Delcorn fictional training tenant content into SharePoint Online.

.DESCRIPTION
  Creates one communication site per department (plus the intranet hub), registers the hub,
  creates document libraries, uploads every file from the SharePoint folder of this pack
  (preserving folders), and creates SharePoint lists from the CSV datasets.

  Re-runnable: existing sites, libraries, lists and files are reused/overwritten.
  ALL CONTENT IS FICTIONAL TRAINING DATA.

.REQUIREMENTS
  * PowerShell 7.4+  and  Install-Module PnP.PowerShell -Scope CurrentUser
  * An Entra ID app registration for PnP interactive login (one-off, see README.md):
      Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP Training Provisioning" -Tenant <tenant>.onmicrosoft.com
  * SharePoint Administrator rights (to create sites).

.EXAMPLE
  ./Provision-SharePoint.ps1 -TenantName contoso -ClientId 00000000-0000-0000-0000-000000000000
#>
param(
    [Parameter(Mandatory)] [string]$TenantName,
    [Parameter(Mandatory)] [string]$ClientId,
    [string]$SitePrefix = 'DLC',
    [string]$OwnerEmail,
    [int]$MaxListRows = 300,
    [switch]$SkipFiles,
    [switch]$SkipLists,
    [string[]]$OnlySites
)
$ErrorActionPreference = 'Stop'
$PackRoot  = Split-Path -Parent $PSScriptRoot
$SpRoot    = Join-Path $PackRoot 'SharePoint'
$DataRoot  = Join-Path $PackRoot 'Databases' 'csv'
$BaseUrl   = "https://$TenantName.sharepoint.com"
$AdminUrl  = "https://$TenantName-admin.sharepoint.com"

$Sites = @(
    @{Key='hub'; Title='Delcorn Hub'; Alias='Hub'; Folder='Delcorn Hub'; Description='The home of Delcorn: news, company-wide policies, templates and brand.'; IsHub=$true; Libraries=@(@{Title='News'; Url='News'}, @{Title='Company Policies'; Url='CompanyPolicies'}, @{Title='Templates'; Url='Templates'}, @{Title='Brand & Comms'; Url='BrandComms'})}
    @{Key='exec'; Title='Executive & Board'; Alias='Exec'; Folder='Executive & Board'; Description='Board papers, strategy, risk and governance. Restricted to the executive team and board.'; IsHub=$false; Libraries=@(@{Title='Board Packs'; Url='BoardPacks'}, @{Title='Strategy'; Url='Strategy'}, @{Title='Risk & Governance'; Url='RiskGovernance'})}
    @{Key='delivery'; Title='Learning Delivery'; Alias='Delivery'; Folder='Learning Delivery'; Description='Everything skills coaches and delivery managers need: caseloads, learner files, coaching resources and team records.'; IsHub=$false; Libraries=@(@{Title='Coaching Resources'; Url='CoachingResources'}, @{Title='Learner Files'; Url='LearnerFiles'}, @{Title='Caseload Reports'; Url='CaseloadReports'}, @{Title='Team Records'; Url='TeamRecords'})}
    @{Key='curriculum'; Title='Curriculum & Academies'; Alias='Curriculum'; Folder='Curriculum & Academies'; Description='Programme specifications, curriculum plans and workshop materials for the AI, Data, Digital, Leadership and People academies.'; IsHub=$false; Libraries=@(@{Title='Programme Specifications'; Url='ProgrammeSpecifications'}, @{Title='Workshop Materials'; Url='WorkshopMaterials'}, @{Title='Curriculum Planning'; Url='CurriculumPlanning'})}
    @{Key='quality'; Title='Quality & Compliance'; Alias='Quality'; Folder='Quality & Compliance'; Description='Ofsted readiness, self-assessment, quality improvement, observations and funding compliance.'; IsHub=$false; Libraries=@(@{Title='Ofsted & Inspection'; Url='OfstedInspection'}, @{Title='Self-Assessment & QIP'; Url='SelfAssessmentQip'}, @{Title='Observations'; Url='Observations'}, @{Title='Gateway & EPA'; Url='GatewayEpa'}, @{Title='Policies & Procedures'; Url='PoliciesProcedures'})}
    @{Key='safeguarding'; Title='Safeguarding & Learner Support'; Alias='Safeguarding'; Folder='Safeguarding & Learner Support'; Description='Safeguarding, Prevent, wellbeing and additional learning support. Case records are restricted to the safeguarding team.'; IsHub=$false; Libraries=@(@{Title='Policies & Guidance'; Url='PoliciesGuidance'}, @{Title='Training & Briefings'; Url='TrainingBriefings'}, @{Title='Learner Support'; Url='LearnerSupport'}, @{Title='Case Management'; Url='CaseManagement'})}
    @{Key='partnerships'; Title='Employer Partnerships'; Alias='Partnerships'; Folder='Employer Partnerships'; Description='Client accounts, proposals, contracts, case studies and marketing for our employer partners.'; IsHub=$false; Libraries=@(@{Title='Proposals'; Url='Proposals'}, @{Title='Account Plans'; Url='AccountPlans'}, @{Title='Contracts & Agreements'; Url='ContractsAgreements'}, @{Title='Case Studies'; Url='CaseStudies'}, @{Title='Correspondence'; Url='Correspondence'})}
    @{Key='finance'; Title='Finance & Funding'; Alias='Finance'; Folder='Finance & Funding'; Description='Management accounts, budgets, apprenticeship funding, ILR returns and procurement.'; IsHub=$false; Libraries=@(@{Title='Management Accounts'; Url='ManagementAccounts'}, @{Title='Funding & ILR'; Url='FundingIlr'}, @{Title='Budgets & Forecasts'; Url='BudgetsForecasts'}, @{Title='Procurement & Suppliers'; Url='ProcurementSuppliers'}, @{Title='Invoices'; Url='Invoices'})}
    @{Key='people'; Title='People & Culture'; Alias='People'; Folder='People & Culture'; Description='HR policies, recruitment, onboarding, CPD and wellbeing for Delcorn staff.'; IsHub=$false; Libraries=@(@{Title='HR Policies'; Url='HrPolicies'}, @{Title='Recruitment'; Url='Recruitment'}, @{Title='Onboarding'; Url='Onboarding'}, @{Title='CPD & Development'; Url='CpdDevelopment'}, @{Title='Wellbeing'; Url='Wellbeing'})}
    @{Key='tech'; Title='Learning Technology & IT'; Alias='Tech'; Folder='Learning Technology & IT'; Description='IT and data policies, systems documentation, projects and service desk.'; IsHub=$false; Libraries=@(@{Title='IT & Data Policies'; Url='ItDataPolicies'}, @{Title='Systems & Data'; Url='SystemsData'}, @{Title='Projects'; Url='Projects'}, @{Title='Service Desk'; Url='ServiceDesk'})}
)

$Lists = @(
    @{Site='Partnerships'; Title='Sales Pipeline'; Url='Lists/SalesPipeline'; Csv='opportunities.csv'; Columns=@(@{Name='opp_id'; Internal='OppId'; Type='Text'}, @{Name='employer_id'; Internal='EmployerId'; Type='Text'}, @{Name='employer_name'; Internal='EmployerName'; Type='Text'}, @{Name='owner_id'; Internal='OwnerId'; Type='Text'}, @{Name='programme_code'; Internal='ProgrammeCode'; Type='Text'}, @{Name='programme_name'; Internal='ProgrammeName'; Type='Text'}, @{Name='opportunity_name'; Internal='OpportunityName'; Type='Text'}, @{Name='stage'; Internal='Stage'; Type='Text'}, @{Name='probability'; Internal='Probability'; Type='Number'}, @{Name='est_starts'; Internal='EstStarts'; Type='Number'}, @{Name='est_value_gbp'; Internal='EstValueGbp'; Type='Number'}, @{Name='weighted_value_gbp'; Internal='WeightedValueGbp'; Type='Number'}, @{Name='created_date'; Internal='CreatedDate'; Type='DateTime'}, @{Name='expected_close'; Internal='ExpectedClose'; Type='Text'}, @{Name='source'; Internal='Source'; Type='Text'}, @{Name='funding_route'; Internal='FundingRoute'; Type='Text'})}
    @{Site='Tech'; Title='Service Desk Tickets'; Url='Lists/ServiceDeskTickets'; Csv='it_tickets.csv'; Columns=@(@{Name='ticket_id'; Internal='TicketId'; Type='Text'}, @{Name='raised_by'; Internal='RaisedBy'; Type='Text'}, @{Name='raised_by_name'; Internal='RaisedByName'; Type='Text'}, @{Name='department'; Internal='Department'; Type='Text'}, @{Name='category'; Internal='Category'; Type='Text'}, @{Name='priority'; Internal='Priority'; Type='Text'}, @{Name='opened'; Internal='Opened'; Type='Text'}, @{Name='sla_target_hours'; Internal='SlaTargetHours'; Type='Number'}, @{Name='status'; Internal='Status'; Type='Text'}, @{Name='resolution_hours'; Internal='ResolutionHours'; Type='Number'}, @{Name='resolved'; Internal='Resolved'; Type='Text'}, @{Name='sla_met'; Internal='SlaMet'; Type='Number'}, @{Name='assigned_to'; Internal='AssignedTo'; Type='Text'})}
    @{Site='Exec'; Title='Corporate Risk Register'; Url='Lists/CorporateRiskRegister'; Csv='risk_register.csv'; Columns=@(@{Name='risk_id'; Internal='RiskId'; Type='Text'}, @{Name='title'; Internal='Title'; Type='Text'}, @{Name='category'; Internal='Category'; Type='Text'}, @{Name='owner_id'; Internal='OwnerId'; Type='Text'}, @{Name='likelihood'; Internal='Likelihood'; Type='Number'}, @{Name='impact'; Internal='Impact'; Type='Number'}, @{Name='inherent_score'; Internal='InherentScore'; Type='Number'}, @{Name='key_controls'; Internal='KeyControls'; Type='Text'}, @{Name='residual_score'; Internal='ResidualScore'; Type='Number'}, @{Name='trend'; Internal='Trend'; Type='Text'}, @{Name='last_reviewed'; Internal='LastReviewed'; Type='Text'})}
    @{Site='Finance'; Title='Supplier Register'; Url='Lists/SupplierRegister'; Csv='suppliers.csv'; Columns=@(@{Name='supplier_id'; Internal='SupplierId'; Type='Text'}, @{Name='supplier_name'; Internal='SupplierName'; Type='Text'}, @{Name='category'; Internal='Category'; Type='Text'}, @{Name='annual_spend_gbp'; Internal='AnnualSpendGbp'; Type='Number'}, @{Name='contract_start'; Internal='ContractStart'; Type='Text'}, @{Name='contract_end'; Internal='ContractEnd'; Type='Text'}, @{Name='owner_id'; Internal='OwnerId'; Type='Text'}, @{Name='risk_rating'; Internal='RiskRating'; Type='Text'}, @{Name='dpa_in_place'; Internal='DpaInPlace'; Type='Number'})}
    @{Site='Delivery'; Title='Coach Caseloads'; Url='Lists/CoachCaseloads'; Csv='coach_caseloads.csv'; Columns=@(@{Name='coach_id'; Internal='CoachId'; Type='Text'}, @{Name='coach_name'; Internal='CoachName'; Type='Text'}, @{Name='academy'; Internal='Academy'; Type='Text'}, @{Name='manager_id'; Internal='ManagerId'; Type='Text'}, @{Name='caseload_target'; Internal='CaseloadTarget'; Type='Number'}, @{Name='active_learners'; Internal='ActiveLearners'; Type='Number'}, @{Name='green'; Internal='Green'; Type='Number'}, @{Name='amber'; Internal='Amber'; Type='Number'}, @{Name='red'; Internal='Red'; Type='Number'}, @{Name='overdue_reviews'; Internal='OverdueReviews'; Type='Number'}, @{Name='capacity_used'; Internal='CapacityUsed'; Type='Number'})}
)

function Site-Url($alias) { "$BaseUrl/sites/$SitePrefix-$alias" }

Write-Host "Connecting to SharePoint admin ($AdminUrl)..." -ForegroundColor Cyan
Connect-PnPOnline -Url $AdminUrl -Interactive -ClientId $ClientId
if (-not $OwnerEmail) { $OwnerEmail = (Get-PnPProperty -ClientObject (Get-PnPWeb) -Property CurrentUser).Email }

# ---- 1. Sites ---------------------------------------------------------------------------
foreach ($s in $Sites) {
    if ($OnlySites -and $s.Key -notin $OnlySites) { continue }
    $url = Site-Url $s.Alias
    $existing = Get-PnPTenantSite -Identity $url -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "Creating site $($s.Title) -> $url" -ForegroundColor Green
        New-PnPSite -Type CommunicationSite -Title $s.Title -Url $url -Description $s.Description -Owner $OwnerEmail -Wait | Out-Null
    } else { Write-Host "Site exists: $url" }
}

# ---- 2. Hub -----------------------------------------------------------------------------
$hub = $Sites | Where-Object { $_.IsHub } | Select-Object -First 1
if ($hub) {
    $hubUrl = Site-Url $hub.Alias
    try { Register-PnPHubSite -Site $hubUrl -ErrorAction Stop | Out-Null; Write-Host "Registered hub $hubUrl" }
    catch { Write-Host "Hub already registered (or no permission): $($_.Exception.Message)" -ForegroundColor Yellow }
    foreach ($s in $Sites | Where-Object { -not $_.IsHub }) {
        if ($OnlySites -and $s.Key -notin $OnlySites) { continue }
        try { Add-PnPHubSiteAssociation -Site (Site-Url $s.Alias) -HubSite $hubUrl -ErrorAction Stop } catch { }
    }
}

# ---- 3. Libraries + files ---------------------------------------------------------------
foreach ($s in $Sites) {
    if ($OnlySites -and $s.Key -notin $OnlySites) { continue }
    $url = Site-Url $s.Alias
    Connect-PnPOnline -Url $url -Interactive -ClientId $ClientId
    foreach ($lib in $s.Libraries) {
        if (-not (Get-PnPList -Identity $lib.Url -ErrorAction SilentlyContinue)) {
            New-PnPList -Title $lib.Title -Url $lib.Url -Template DocumentLibrary -OnQuickLaunch | Out-Null
            Write-Host "  + library $($lib.Title)"
        }
        if ($SkipFiles) { continue }
        $local = Join-Path $SpRoot $s.Folder $lib.Title
        if (-not (Test-Path $local)) { continue }
        Get-ChildItem $local -File -Recurse | ForEach-Object {
            $rel = [IO.Path]::GetRelativePath($local, $_.DirectoryName) -replace '\\','/'
            $dest = if ($rel -eq '.') { $lib.Url } else { "$($lib.Url)/$rel" }
            try {
                Add-PnPFile -Path $_.FullName -Folder $dest -Values @{ Modified = $_.LastWriteTime } | Out-Null
            } catch {
                Add-PnPFile -Path $_.FullName -Folder $dest | Out-Null
            }
            Write-Host "    ^ $dest/$($_.Name)"
        }
    }
}

# ---- 4. Lists from CSV ------------------------------------------------------------------
if (-not $SkipLists) {
    foreach ($l in $Lists) {
        $site = $Sites | Where-Object { $_.Alias -eq $l.Site }
        if ($OnlySites -and $site.Key -notin $OnlySites) { continue }
        Connect-PnPOnline -Url (Site-Url $l.Site) -Interactive -ClientId $ClientId
        if (-not (Get-PnPList -Identity $l.Url -ErrorAction SilentlyContinue)) {
            New-PnPList -Title $l.Title -Url $l.Url -Template GenericList -OnQuickLaunch | Out-Null
            foreach ($c in $l.Columns | Select-Object -Skip 1) {
                Add-PnPField -List $l.Url -DisplayName $c.Name -InternalName $c.Internal -Type $c.Type -AddToDefaultView | Out-Null
            }
            Set-PnPField -List $l.Url -Identity 'Title' -Values @{ Title = $l.Columns[0].Name } | Out-Null
            Write-Host "  + list $($l.Title)"
        } else { Write-Host "  list exists, appending rows: $($l.Title)" -ForegroundColor Yellow }
        $rows = Import-Csv (Join-Path $DataRoot $l.Csv) | Select-Object -First $MaxListRows
        $batch = New-PnPBatch
        foreach ($r in $rows) {
            $vals = @{ Title = [string]$r.($l.Columns[0].Name) }
            foreach ($c in $l.Columns | Select-Object -Skip 1) {
                $v = $r.($c.Name)
                if ([string]::IsNullOrWhiteSpace($v)) { continue }
                if ($c.Type -eq 'Boolean') { $v = @('1','true','True','Yes') -contains $v }
                $vals[$c.Internal] = $v
            }
            Add-PnPListItem -List $l.Url -Values $vals -Batch $batch | Out-Null
        }
        Invoke-PnPBatch -Batch $batch
        Write-Host "    $($rows.Count) rows -> $($l.Title)"
    }
}

Write-Host "`nDone. Hub: $(Site-Url ($hub.Alias))" -ForegroundColor Cyan
Write-Host "Note: Microsoft 365 Copilot / search can take several hours to index new content." -ForegroundColor Yellow
