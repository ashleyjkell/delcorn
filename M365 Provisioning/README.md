# Provisioning Delcorn into Microsoft 365

All content in this pack is **fictional** and intended for training use only. Use a training/dev tenant
(e.g. a Microsoft 365 Developer Program tenant), never a production tenant.

## One-off setup

```powershell
# PowerShell 7.4+
Install-Module PnP.PowerShell -Scope CurrentUser
# Create the Entra ID app PnP uses for interactive sign-in (needs admin consent):
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP Training Provisioning" -Tenant <tenant>.onmicrosoft.com
# Note the Client ID it prints.
```

## Run

```powershell
cd "M365 Provisioning"
./Provision-SharePoint.ps1 -TenantName <tenant> -ClientId <client-id>
# Options:
#   -SitePrefix XYZ        prefix for site URLs (default DLC) - use per cohort to avoid clashes
#   -OnlySites hr,finance  provision only some department sites
#   -SkipFiles / -SkipLists
#   -MaxListRows 300       cap rows written to each SharePoint list
#   -LearnerGroup "<name>" Entra security group granted access to every site (created if missing)
#   -LearnerRole Read|Edit site visitors (default) or members
```

## Several fictional companies in one tenant
One tenant can hold many packs: each company's sites use their own prefix (`/sites/DLC-...`) and their own hub.
To keep each cohort on one company, give it a learner group:

```powershell
./Provision-SharePoint.ps1 -TenantName <tenant> -ClientId <client-id> -LearnerGroup "Delcorn Learners"
```

Then add the cohort's learner accounts to that group (Entra admin centre). Creating the group needs the Graph
permission `Group.ReadWrite.All` on the PnP app; without it, create the security group by hand and pass its name.
Copilot only returns content the signed-in user can open, so learners only see their own company. Copilot Studio
agents can also be limited to a single site or library as knowledge. To run two cohorts on the same company, provision
it twice with different `-SitePrefix` values.

## Removing a company

```powershell
./Remove-Company.ps1 -TenantName <tenant> -ClientId <client-id>          # sites go to the recycle bin (93 days)
./Remove-Company.ps1 -TenantName <tenant> -ClientId <client-id> -Purge -RemoveGroup "Delcorn Learners"
```

This deletes only this pack's sites (matched by prefix). It asks you to type the prefix to confirm; `-Force` skips that.

## What gets created

| Site | URL | Libraries |
|---|---|---|
| Delcorn Hub (hub) | /sites/DLC-Hub | News, Company Policies, Templates, Brand & Comms |
| Executive & Board | /sites/DLC-Exec | Board Packs, Strategy, Risk & Governance |
| Learning Delivery | /sites/DLC-Delivery | Coaching Resources, Learner Files, Caseload Reports, Team Records, Communications Archive |
| Curriculum & Academies | /sites/DLC-Curriculum | Programme Specifications, Workshop Materials, Curriculum Planning |
| Quality & Compliance | /sites/DLC-Quality | Ofsted & Inspection, Self-Assessment & QIP, Observations, Gateway & EPA, Policies & Procedures |
| Safeguarding & Learner Support | /sites/DLC-Safeguarding | Policies & Guidance, Training & Briefings, Learner Support, Case Management |
| Employer Partnerships | /sites/DLC-Partnerships | Proposals, Account Plans, Contracts & Agreements, Case Studies, Correspondence |
| Finance & Funding | /sites/DLC-Finance | Management Accounts, Funding & ILR, Budgets & Forecasts, Procurement & Suppliers, Invoices, Communications Archive |
| People & Culture | /sites/DLC-People | HR Policies, Recruitment, Onboarding, CPD & Development, Wellbeing |
| Learning Technology & IT | /sites/DLC-Tech | IT & Data Policies, Systems & Data, Projects, Service Desk, Communications Archive |

SharePoint lists: Sales Pipeline (Partnerships), Service Desk Tickets (Tech), Corporate Risk Register (Exec), Supplier Register (Finance), Coach Caseloads (Delivery)

## Not provisioned automatically
* **Emails** (`Communications/Email/*.eml`) - drag into an Outlook folder of a training mailbox. Every thread is
  also uploaded as a Word copy to a *Communications Archive* library, so Copilot can find it through SharePoint.
* **Teams chats** (`Communications/Teams`) - Teams history cannot be imported. Each chat is also uploaded as a Word
  transcript to a Communications Archive library.
* **Databases** (`Databases/`) - the SQLite DB/CSVs/Excel workbook are for Power BI, Dataverse imports,
  Copilot Studio knowledge, or Excel Copilot exercises.

## Copilot indexing
New SharePoint content can take a few hours (occasionally up to 24h) before Microsoft 365 Copilot can use it.
Learners need access to each site: use `-LearnerGroup`, or add them as site visitors yourself.
