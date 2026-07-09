-- Commission Tracker shared staff directory.
-- Run this once in Supabase SQL Editor for Option 1: shared staff list.

create table if not exists commission_tracker.staff_directory (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  staff_name text not null,
  email text not null unique,
  status text not null default 'Active'
    check (status in ('Active', 'Disabled')),
  source_app text not null default 'Shared',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

grant usage on schema commission_tracker to anon, authenticated, service_role;
grant select, insert, update, delete on all tables in schema commission_tracker to authenticated, service_role;
grant usage, select on all sequences in schema commission_tracker to authenticated, service_role;
grant execute on all functions in schema commission_tracker to authenticated, service_role;

alter table commission_tracker.staff_directory enable row level security;

drop policy if exists "Users can read own directory row" on commission_tracker.staff_directory;
create policy "Users can read own directory row"
  on commission_tracker.staff_directory for select
  using (auth_user_id = auth.uid());

drop policy if exists "Managers can manage staff directory" on commission_tracker.staff_directory;
create policy "Managers can manage staff directory"
  on commission_tracker.staff_directory for all
  using (commission_tracker.has_commission_permission('manageUsers'))
  with check (commission_tracker.has_commission_permission('manageUsers'));

drop policy if exists "Users can manage user profiles" on commission_tracker.user_profiles;
create policy "Users can manage user profiles"
  on commission_tracker.user_profiles for all
  using (commission_tracker.has_commission_permission('manageUsers'))
  with check (commission_tracker.has_commission_permission('manageUsers'));

drop policy if exists "Users can manage ledger access" on commission_tracker.user_ledger_access;
create policy "Users can manage ledger access"
  on commission_tracker.user_ledger_access for all
  using (commission_tracker.has_commission_permission('manageUsers'))
  with check (commission_tracker.has_commission_permission('manageUsers'));

insert into commission_tracker.staff_directory (
  auth_user_id,
  staff_name,
  email,
  status,
  source_app,
  notes
)
select
  id,
  full_name,
  email,
  status,
  'Commission Tracker',
  notes
from commission_tracker.user_profiles
on conflict (email) do update set
  auth_user_id = excluded.auth_user_id,
  staff_name = excluded.staff_name,
  status = excluded.status,
  source_app = excluded.source_app,
  notes = excluded.notes,
  updated_at = now();
