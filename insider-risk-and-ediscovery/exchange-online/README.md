# Exchange Online

Scripts for the **exchange-online** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `export-user-calendar-events-via-graph.ps1` | An investigation needs a user's calendar items for a given period. | Authenticates with an app registration secret and exports calendar view events (subject, attendees, online meeting info) for a user and date range. | Microsoft.Graph; app registration with Calendars.Read; ImportExcel | read-only | Hard-coded dates and tenant/client IDs as placeholders; Calendars.Read application permission is tenant-wide, so it must be scoped (application access policy) and approved; handle output as personal data. |
