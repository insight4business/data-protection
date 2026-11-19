# Azure Nsg Flow Logs

Scripts for the **azure-nsg-flow-logs** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `nsg-flow-logs-clear-existing-settings.ps1` | Old NSG flow logs settings must be reset before re-onboarding. | Iterates Network Watchers and removes flow log configs (removal commented out). | Az.Network; Network Contributor | destructive | Copy-pasted header says host pools; org storage account IDs; NSG flow logs retire in 2027 |
