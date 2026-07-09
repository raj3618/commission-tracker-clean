# Supabase Setup For Commission Tracker

This is the shared online database and login setup for the Commission Tracker.

## What Supabase Will Do

- Store the same data for all staff.
- Keep Trial, SHIC, and future college ledgers separate.
- Store user access centrally.
- Control which user can open which ledger.
- Prepare real login/security through Supabase Auth.
- Store fees, GST-aware commission, payments, student allocations, and change history.

## Current Stage

This version prepares the Supabase database structure.

The tracker screen is still mostly using browser storage until the next coding stage connects the app screens to Supabase tables.

## Files To Use

- Main database setup:
  `supabase/schema.sql`

- First admin setup:
  `supabase/first-admin-template.sql`

## Step 1 - Create Supabase Project

Create a new Supabase project for the Commission Tracker.

Save these values:

- Project URL
- Anon/public key
- Service role key

The service role key is private. Do not put it inside browser code.

For automatic staff sync, add the service role key only in Render environment variables as:

`SUPABASE_SERVICE_ROLE_KEY`

This lets the secure backend sync safe staff details from Supabase Auth into the shared staff directory. It must never be pasted into `public/commission-calculator.html`.

## Step 2 - Run The Database Script

In Supabase:

1. Open SQL Editor.
2. Paste the full contents of `supabase/schema.sql`.
3. Run it.

This creates inside the `commission_tracker` database area:

- Trial and SHIC ledgers
- User profiles
- User ledger access
- Agents
- Students
- Fee collections
- Bulk fee imports
- Commission payments
- Student payment allocations
- Change history
- Ledger snapshots for shared online app data
- Row-level security rules

## Step 3 - Expose Commission Tracker To Data API

In Supabase:

1. Open **Project Settings**.
2. Open **Data API**.
3. Find **Exposed schemas**.
4. Add:
   `commission_tracker`
5. Save.

This lets the browser app read Commission Tracker tables after the staff member logs in.

Make sure the `commission_tracker.ledger_snapshots` table is also exposed. This
table stores the current live ledger data used by the hosted tracker while the
screens are being moved from browser-only storage to Supabase.

## Step 4 - Create First Admin Login

In Supabase Authentication:

1. Create the first admin user.
2. Copy the Auth user ID.
3. Open `supabase/first-admin-template.sql`.
4. Replace:
   - `YOUR_AUTH_USER_ID_HERE`
   - `YOUR_EMAIL_HERE`
   - `YOUR_NAME_HERE`
5. Run it in SQL Editor.

This gives the first admin full access to Trial and SHIC.

## Step 5 - Add Render Environment Variables

In Render, add:

```text
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

Only the first two are allowed in browser/public code.

The service role key is only for secure server-side/admin jobs.

## Step 6 - Current App Connection

V8 can sign in with an existing Supabase Auth user and load the ledgers that user can access from `commission_tracker.user_ledger_access`.

Operational data is still being saved locally in the browser until the next coding stage connects each work screen to Supabase.

## Step 7 - Next Coding Stage

After Supabase is ready, the next version should connect the app screens to Supabase:

- Login screen
- Load ledgers from Supabase
- Load/save agents
- Load/save fees
- Load/save commission payments
- Load/save user permissions
- Store change history online

## Important Rules

- Student ID is unique.
- One Student ID cannot have two names.
- Fee month is based on collection date.
- Staff-facing dates should show like `12-Mar-26`.
- Fee months should show like `Mar-26`.
- Agent GST changes must not rewrite old transactions.
- Commission payment is allocated student by student.
- Delete/edit/revert actions must stay in change history.
- Single source of truth rule: all dashboards, reports, agent portals, pay
  screens, balances, and exports must calculate from the current live ledger
  records only. If a record is edited, deleted, or reverted, every relevant
  screen must reflect that same change.
- Linked transaction rule: upfront commission records are linked fee and
  commission payment records. Deleting either side must remove the complete
  linked upfront transaction everywhere. Reverting the history item must restore
  all linked records together.

## Password And Session Rule

When a staff member changes their own password, or an administrator resets a
staff member's password, that staff member must be logged out from all active
sessions on all devices.

The staff member must sign in again using the new password before using the
Commission Tracker again.

This rule must be enforced through Supabase Auth/server-side session revocation.
The browser screen alone is not enough, because a user may already be logged in
on another computer, phone, or browser.

Operational protocol:

1. Change or reset the staff member's password in Supabase/Auth.
2. Revoke/sign out all sessions for that user.
3. Ask the staff member to sign in again with the new password.
4. Record the password reset/session revocation in admin notes or change
   history where available.

## Shared Link And Login Safety Rule

Commission Tracker links must never carry login access.

If a logged-in staff member copies or shares a link, the receiver must not
inherit the sender's login, password, token, ledger access, or permissions. The
receiver must sign in with their own Supabase account before opening a ledger.

The app must follow these rules:

- No access token is placed in the URL.
- No password is placed in the URL.
- No auto-login is allowed from a copied link.
- Each browser/device checks its own Supabase session.
- If no valid session exists, the login screen is shown first.
- If a link contains password/token-looking fields, the app removes them from
  the URL and requires sign-in again.

