# Commission Tracker

Standalone Commission Tracker prepared for GitHub, Render, and Supabase.

Current package version: V8 - Supabase login ready.

## Current Status

The current working tracker is still a browser-based standalone file. It has
been copied into this project at:

```text
public/commission-calculator.html
```

After hosting, staff can open:

```text
/commission-calculator.html
```

This keeps the existing tracker usable while the Supabase-backed version is
built.

## What The Tracker Does

- Records student fees collected by agents.
- Records refunds and negative fee adjustments.
- Calculates GST-aware commission payable.
- Supports GST inclusive, GST exclusive, and no GST agents.
- Tracks student-wise commission paid.
- Supports bulk fee entry from Excel.
- Supports upfront commission retained by agents.
- Tracks agent invoice numbers.
- Provides reports, Excel/CSV exports, and change history.

## Important Current Limitation

The standalone HTML version still saves operational data in the browser on one
computer. This is not suitable for multiple staff using different computers.

V8 prepares the Supabase database structure and user-access model, then adds a
first browser sign-in step. The app can sign in with existing Supabase Auth
users and read allowed Commission Tracker ledgers.

The next proper version should connect agents, fees, payments, reports, and
change history to Supabase tables.

## Recommended Hosting Plan

1. Push this folder to GitHub.
2. Connect the GitHub repo to Render.
3. Deploy the web app on Render.
4. Create a Supabase project.
5. Add the database tables from `supabase/schema.sql`.
6. Create the first admin using `supabase/first-admin-template.sql`.
7. Convert the tracker from browser storage to Supabase storage.
8. Add real login and user permissions through Supabase Auth.

## Recommended Render Settings

- Build command: `npm install && npm run build`
- Start command: `npm run start`
- Node version: `22`

The included `render.yaml` can be used as a starting point.

## Supabase Notes

Use Supabase for:

- Live shared database
- Staff login
- User permissions
- Agent-level access
- Audit/change history
- Backups
- Shared ledger data through `commission_tracker.ledger_snapshots`

Key rules to preserve:

- Student ID is unique.
- One Student ID cannot have two different names.
- GST treatment is saved on each fee transaction.
- Agent GST changes must not rewrite old fee entries.
- Commission payments are allocated student by student.
- Edit/delete/revert actions must be recorded in change history.
- Single source of truth rule: every report, portal, pay page, export, and
  balance must calculate only from the current live ledger records. If a fee,
  commission payment, upfront commission, bulk import, agent, or linked record
  is edited, deleted, or reverted, the change must flow everywhere it is
  relevant. No page should keep an old copied value after the source record has
  changed.
- Linked transaction rule: upfront commission creates linked fee and commission
  payment records. Deleting either side must delete the full linked upfront
  transaction everywhere and record it in Change History. Reverting that history
  item must restore the linked records together.

## Suggested Future Screens

- Dashboard
- Agents List
- Agent Portal
- Collect Fees
- Collect Fee Bulk
- Upfront Commission
- Pay Student Commission
- Reports
- Change History
- User Management

## User Management Timing

The standalone screen has central user-management planning. Real enforcement
must come from Supabase Auth and row-level security.

V6 includes Supabase tables for:

- Central user profiles
- Custom permissions
- Ledger access per user
- Trial and SHIC as starter ledgers

## Password Session Rule

If a user changes their own password, or an administrator resets a user's
password, that user must be logged out from all active sessions on all devices.

The user must log in again with the new password before using the Commission
Tracker. This must be handled through Supabase Auth/server-side session
revocation, not only through the browser page.

## Shared Link Session Rule

Sharing a Commission Tracker link must not share login access. The link must not
contain a password, access token, refresh token, or hidden login details.

If another staff member opens a shared link, they must log in with their own
Supabase account and only see the ledgers/pages allowed for them.
