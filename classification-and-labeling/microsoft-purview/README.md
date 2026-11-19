# Microsoft Purview

Scripts for the **microsoft-purview** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `fix-rights-management-inactive-for-tenant.md` | Sensitivity labels or encryption fail with RmsInactiveForTenantException. | Troubleshooting notes: install AIPService, connect, check status, run Enable-AipService, plus causes (license, older tenant). | AIPService module; Global Administrator | changes-state | Pasted web text with stray fragments ('Microsoft Learn', '+3') and no executable script; clean up and convert to a markdown runbook. |
