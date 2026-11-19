# Problem solved : An investigation needs a user's calendar items for a given period.
# What it does    : Authenticates with an app registration secret and exports calendar view events (subject, attendees, online meeting info) for a user and date range.
# Requires        : Microsoft.Graph; app registration with Calendars.Read; ImportExcel
# Effect          : read-only
# Known issues    : Hard-coded dates and tenant/client IDs as placeholders; Calendars.Read application permission is tenant-wide, so it must be scoped (application access policy) and approved; handle output as personal data.
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###
# Install-Module Microsoft.Graph
# Install-Module ImportExcel
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Calendar
Import-Module ImportExcel

# Necessário API permissions:
# Calendars.Read
# User.Read

# Parametros
$user = "ENTRE_AQUI_COM_SEU_EMAIL@example.com"
$StartDate = "2024-07-01T00:00:00Z"
$EndDate = "2024-09-01T00:00:00Z"

# Autenticação via App Registration + Client Secret
$ClientSecretCredential = Get-Credential -Credential "ENTRE_AQUI_COM_SEU_ID"
Connect-MgGraph -TenantId "ENTRE_AQUI_COM_SEU_ID" -ClientSecretCredential $ClientSecretCredential

# List calendars
Get-MgUserCalendar -All -UserId $user

# View events
# $calendarView = Get-MgUserCalendarView -UserId $user -CalendarId "Calendar" -StartDateTime $StartDate -EndDateTime $EndDate
$calendarView = Get-MgUserCalendarView -All -UserId $user -StartDateTime $StartDate -EndDateTime $EndDate | Select-Object Id, Subject, BodyPreview, Attendees, IsAllDay, IsCancelled, IsDraft, IsOnlineMeeting, IsOrganizer, LastModifiedDateTime, OnlineMeeting, OnlineMeetingProvider, OnlineMeetingUrl, Start, End, Type, ShowAs

$report = [System.Collections.Generic.List[Object]]::new()
foreach ($cv in $calendarView) {
    $accepted = @()
    $rejected = @()
    $tentative = @()
    $noResponse = @()

    foreach ($a in $cv.Attendees) {
        if ($a.Status.Response -eq "accepted") {
            $accepted += $a.EmailAddress.Address
        } elseif ($a.Status.Response -eq "rejected") {
            $rejected += $a.EmailAddress.Address
        } elseif ($a.Status.Response -eq "tentative") {
            $tentative += $a.EmailAddress.Address
        } elseif ($a.Status.Response -eq "none" -or $a.Status.Response -eq "notResponded") {
            $noResponse += $a.EmailAddress.Address
        } else {
            Write-Host "Unknown response: $($a.Status.Response)"
        }
    }

    $cv | Add-Member -MemberType NoteProperty -Name "Attendees_Accepted" -Value ($accepted -join ",")
    $cv | Add-Member -MemberType NoteProperty -Name "Attendees_Rejected" -Value ($rejected -join ",")
    $cv | Add-Member -MemberType NoteProperty -Name "Attendees_Tentative" -Value ($tentative -join ",")
    $cv | Add-Member -MemberType NoteProperty -Name "Attendees_NoResponse" -Value ($noResponse -join ",")

    if ($cv.OnlineMeetingUrl -eq $null) {
        $cv.OnlineMeetingUrl = $cv.OnlineMeeting.JoinUrl
    }

    $cv | Add-Member -MemberType NoteProperty -Name "StartDateTimeUTC" -Value $cv.Start.DateTime
    $cv | Add-Member -MemberType NoteProperty -Name "EndDateTimeUTC" -Value $cv.End.DateTime

    $cv = $cv | Select-Object * -ExcludeProperty Attendees, OnlineMeeting, Start, End
    $report.Add($cv)
}

# $calendarView | Export-Excel

$report | Export-Excel -AutoSize
