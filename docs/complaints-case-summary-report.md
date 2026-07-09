# Complaints Case Summary Report & Daily Email

Closes [#5](https://github.com/mwhisker/claude-salesforce-demo/issues/5).

This feature adds a report that summarizes all open `Case` records of type
`Complaint`, and a Scheduled-Triggered Flow that emails that summary every
day at 8:00 AM UTC.

## Metadata included

| Component     | Path                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------ |
| Report folder | `force-app/main/default/reports/Complaint_Reports.reportFolder-meta.xml`                   |
| Report        | `force-app/main/default/reports/Complaint_Reports/Complaints_Case_Summary.report-meta.xml` |
| Flow          | `force-app/main/default/flows/Complaints_Case_Summary_Daily_Email.flow-meta.xml`           |

### Report: Complaints Case Summary

- Report type: `CaseList`
- Filter: `Type equals Complaint`
- Grouped by: `Status`
- Columns: Case Number, Subject, Contact Name, Priority, Case Origin, Created Date

### Flow: Complaints Case Summary Daily Email

- Type: Scheduled-Triggered Flow (`AutoLaunchedFlow`), runs `Daily` at `08:00 AM UTC`
  (the flow's `startTime` is stored as `08:00:00.000Z`; adjust it if you need
  the summary sent at 8:00 AM in a different time zone)
- Queries all open (`IsClosed = false`) `Case` records where `Type = Complaint`
- Builds a plain-text summary of the matching cases
- Emails the summary to the address configured in the `RecipientEmail`
  input variable (defaults to the placeholder
  `REPLACE_WITH_RECIPIENT_EMAIL@yourorg.com`, which **must** be updated
  before activating the flow) using
  the current running user as the sender
- If there are no open complaint cases, a short "no complaints today" email
  is sent instead

## Setup required before deploying

1. **Case Type picklist value** — the standard `Case.Type` field must have a
   `Complaint` value available. This repository does not modify the standard
   picklist metadata (to avoid overwriting existing org values on deploy).
   Add `Complaint` as a picklist value on `Case.Type` in Setup before
   deploying/activating the flow, if it does not already exist.
2. **Recipient email** — update the `RecipientEmail` variable's default value
   in the flow (or set it when invoking/scheduling the flow) to the address
   that should receive the daily summary.
3. **Deploy** — deploy the report folder, report, and flow with
   `npm run deploy` (or `sf project deploy start`). The flow is deployed with
   `Active` status so the daily schedule starts as soon as it is deployed.
