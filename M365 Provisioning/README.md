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
```

## What gets created

| Site | URL | Libraries |
|---|---|---|
| Delcorn Hub (hub) | /sites/DLC-Hub | News, Company Policies, Templates, Brand & Comms |
| Executive & Board | /sites/DLC-Exec | Board Packs, Strategy, Risk & Governance |
| Learning Delivery | /sites/DLC-Delivery | Coaching Resources, Learner Files, Caseload Reports, Team Records |
| Curriculum & Academies | /sites/DLC-Curriculum | Programme Specifications, Workshop Materials, Curriculum Planning |
| Quality & Compliance | /sites/DLC-Quality | Ofsted & Inspection, Self-Assessment & QIP, Observations, Gateway & EPA, Policies & Procedures |
| Safeguarding & Learner Support | /sites/DLC-Safeguarding | Policies & Guidance, Training & Briefings, Learner Support, Case Management |
| Employer Partnerships | /sites/DLC-Partnerships | Proposals, Account Plans, Contracts & Agreements, Case Studies, Correspondence |
| Finance & Funding | /sites/DLC-Finance | Management Accounts, Funding & ILR, Budgets & Forecasts, Procurement & Suppliers, Invoices |
| People & Culture | /sites/DLC-People | HR Policies, Recruitment, Onboarding, CPD & Development, Wellbeing |
| Learning Technology & IT | /sites/DLC-Tech | IT & Data Policies, Systems & Data, Projects, Service Desk |

SharePoint lists: Sales Pipeline (Partnerships), Service Desk Tickets (Tech), Corporate Risk Register (Exec), Supplier Register (Finance), Coach Caseloads (Delivery)

## Not provisioned automatically
* **Emails** (`Communications/Email/*.eml`) - drag into an Outlook folder of a training mailbox, or upload the
  thread folders to a library if you want Copilot to ground on them via SharePoint.
* **Teams chats** (`Communications/Teams`) - Teams history cannot be imported; use the HTML transcripts as reference
  material or post them into a channel's Files tab.
* **Databases** (`Databases/`) - the SQLite DB/CSVs/Excel workbook are for Power BI, Dataverse imports,
  Copilot Studio knowledge, or Excel Copilot exercises.

## Copilot indexing
New SharePoint content can take a few hours (occasionally up to 24h) before Microsoft 365 Copilot can use it.
Make sure learner accounts are members/visitors of each site (communication sites default to owner-only + org visitors
depending on tenant sharing settings).
