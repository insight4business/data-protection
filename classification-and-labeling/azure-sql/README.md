# Azure Sql

Scripts for the **azure-sql** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `sql-export-data-classification-applied-and-recommended.ps1` | I need to know sensitive columns found vs already labeled. | Exports applied and recommended classifications. | Az.Sql | read-only |  |
