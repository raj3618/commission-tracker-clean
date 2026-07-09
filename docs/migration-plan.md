# Commission Tracker Migration Plan

## Phase 1: GitHub And Render

- Create a clean GitHub repository for `commission-tracker`.
- Push the contents of `work/commission-calculator`.
- Connect the repo to Render.
- Deploy the current app so `public/commission-calculator.html` is available
  online.

This phase hosts the current standalone tracker but still uses browser storage.

## Phase 2: Supabase Database

- Create a Supabase project.
- Run and review `supabase/schema.sql`.
- Add Supabase environment variables to Render.
- Convert data storage from browser local storage to Supabase tables.

## Mapping Rules

- Staff-facing dates must display as `12-Mar-26`.
- Fee months must display as `Mar-26`.
- Internal database dates may be stored as ISO dates, but every staff screen,
  report, and export should convert them back to the staff-facing format.
- In commission payment screens, staff should select either fee month/s or a
  custom date range, not both together.

## Phase 3: Login And Permissions

- Enable Supabase Auth.
- Add user profiles and permissions.
- Add roles:
  - Admin
  - Accounts Manager
  - Accounts Staff
  - View Only
  - Custom
- Add copy-access-from-existing-user for custom users.
- Add agent-level access control.

## Phase 4: Data Migration

- Export any browser ledger data from the standalone tracker.
- Import agents, students, fees, payments, and change history into Supabase.
- Validate totals against the old standalone tracker.

## Phase 5: Production Controls

- Add automatic database backups.
- Add audit logging for all write actions.
- Add safe delete/revert workflows.
- Add testing for GST and commission calculations.
- Lock down service-role keys so they are never exposed to the browser.
