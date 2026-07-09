-- First admin template.
-- Use after creating your first staff user in Supabase Authentication.
--
-- Replace:
--   YOUR_AUTH_USER_ID_HERE with the user's Supabase Auth UID
--   YOUR_EMAIL_HERE with the user's login email
--   YOUR_NAME_HERE with the staff/admin name

insert into commission_tracker.user_profiles (
  id,
  full_name,
  email,
  status,
  permissions,
  notes
) values (
  'YOUR_AUTH_USER_ID_HERE',
  'YOUR_NAME_HERE',
  'YOUR_EMAIL_HERE',
  'Active',
  array[
    'viewTracker',
    'viewDashboard',
    'viewAgentsList',
    'viewAgentPortal',
    'viewChangeHistory',
    'addAgent',
    'editAgent',
    'disableAgent',
    'deleteAgent',
    'viewAgentGst',
    'addFee',
    'addBulkFee',
    'editFee',
    'deleteFee',
    'deleteBulk',
    'openBulk',
    'importFeeCsv',
    'viewPayCommission',
    'payCommission',
    'payClaimBack',
    'editCommissionPayment',
    'deleteCommissionPayment',
    'updateInvoice',
    'viewInvoices',
    'addUpfront',
    'editUpfront',
    'deleteUpfront',
    'viewReports',
    'viewFeesReports',
    'viewCommissionReports',
    'viewPaidReports',
    'viewBalanceReports',
    'viewStudentReports',
    'viewActualSummary',
    'exportReports',
    'revertChanges',
    'resetLedger',
    'downloadBackup',
    'importBackup',
    'manageUsers'
  ],
  'First Commission Tracker admin'
)
on conflict (id) do update set
  full_name = excluded.full_name,
  email = excluded.email,
  status = excluded.status,
  permissions = excluded.permissions,
  notes = excluded.notes,
  updated_at = now();

insert into commission_tracker.staff_directory (
  auth_user_id,
  staff_name,
  email,
  status,
  source_app,
  notes
) values (
  'YOUR_AUTH_USER_ID_HERE',
  'YOUR_NAME_HERE',
  'YOUR_EMAIL_HERE',
  'Active',
  'Commission Tracker',
  'First Commission Tracker admin'
)
on conflict (email) do update set
  auth_user_id = excluded.auth_user_id,
  staff_name = excluded.staff_name,
  status = excluded.status,
  source_app = excluded.source_app,
  notes = excluded.notes,
  updated_at = now();

insert into commission_tracker.user_ledger_access (user_id, ledger_id)
select 'YOUR_AUTH_USER_ID_HERE', id
from commission_tracker.commission_ledgers
where ledger_name in ('Trial', 'SHIC')
on conflict do nothing;

