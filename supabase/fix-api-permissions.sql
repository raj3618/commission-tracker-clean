-- Commission Tracker API permission fix.
-- Run this in Supabase SQL Editor if login works briefly, then the app cannot read commission_tracker.

grant usage on schema commission_tracker to anon, authenticated, service_role;
grant select, insert, update, delete on all tables in schema commission_tracker to authenticated, service_role;
grant usage, select on all sequences in schema commission_tracker to authenticated, service_role;
grant execute on all functions in schema commission_tracker to authenticated, service_role;

-- Optional check: this confirms your admin user has a Commission Tracker profile.
select id, full_name, email, status
from commission_tracker.user_profiles
where id = 'f4d61213-de2e-4873-9abe-e3b5de29018f';

-- Optional check: this confirms your admin user has at least one ledger assigned.
select access.user_id, ledger.ledger_name, ledger.status
from commission_tracker.user_ledger_access access
join commission_tracker.commission_ledgers ledger on ledger.id = access.ledger_id
where access.user_id = 'f4d61213-de2e-4873-9abe-e3b5de29018f';
