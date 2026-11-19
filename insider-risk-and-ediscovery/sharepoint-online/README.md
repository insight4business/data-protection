# Sharepoint Online

Scripts for the **sharepoint-online** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `summarise-sharepoint-sharing-audit-export.ps1` | We cannot easily review who shared SharePoint content (links, group adds) from the audit log. | Reads audit log CSV exports, parses AuditData JSON, filters out personal sites and builds a sharing activity report. | Audit log CSV exports from Purview; ImportExcel (assumed) | read-only | Input file paths are placeholders; relies on manual download of the audit search results; filter logic partly truncated in the sanitised copy. |
