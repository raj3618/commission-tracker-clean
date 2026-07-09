-- Commission Tracker Supabase schema.
-- Uses its own commission_tracker schema so it does not clash with existing SHIC platform tables.
-- Run this in Supabase SQL Editor for the shared online database.
-- This script prepares ledgers, staff profiles, ledger access, GST-aware fees,
-- student-wise commission payments, reports, and change history.

create extension if not exists pgcrypto;
create schema if not exists commission_tracker;

grant usage on schema commission_tracker to anon, authenticated, service_role;

create table if not exists commission_tracker.commission_ledgers (
  id uuid primary key default gen_random_uuid(),
  ledger_name text not null unique,
  status text not null default 'Active'
    check (status in ('Active', 'Disabled')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into commission_tracker.commission_ledgers (ledger_name, notes)
values
  ('Trial', 'Testing and setup ledger'),
  ('SHIC', 'Separate SHIC commission ledger')
on conflict (ledger_name) do nothing;

create table if not exists commission_tracker.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  status text not null default 'Active'
    check (status in ('Active', 'Disabled')),
  permissions text[] not null default '{}'::text[],
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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

create table if not exists commission_tracker.user_ledger_access (
  user_id uuid not null references commission_tracker.user_profiles(id) on delete cascade,
  ledger_id uuid not null references commission_tracker.commission_ledgers(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, ledger_id)
);

create table if not exists commission_tracker.agents (
  id uuid primary key default gen_random_uuid(),
  ledger_id uuid not null references commission_tracker.commission_ledgers(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  status text not null default 'Active'
    check (status in ('Active', 'Disabled')),
  default_commission_rate numeric(8,2),
  gst_treatment text not null default 'none'
    check (gst_treatment in ('none', 'inclusive', 'exclusive')),
  gst_rate numeric(8,2) not null default 10,
  payment_details text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists agents_ledger_name_unique_idx
  on commission_tracker.agents(ledger_id, lower(name));

create table if not exists commission_tracker.students (
  id uuid primary key default gen_random_uuid(),
  student_id text not null unique,
  student_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists commission_tracker.bulk_fee_imports (
  id uuid primary key default gen_random_uuid(),
  ledger_id uuid not null references commission_tracker.commission_ledgers(id) on delete cascade,
  bulk_name text not null,
  import_date date not null default current_date,
  row_count integer not null default 0,
  imported_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists commission_tracker.fee_collections (
  id uuid primary key default gen_random_uuid(),
  ledger_id uuid not null references commission_tracker.commission_ledgers(id) on delete cascade,
  agent_id uuid not null references commission_tracker.agents(id),
  student_id uuid not null references commission_tracker.students(id),
  collection_date date not null,
  fee_month text not null,
  fees_paid numeric(12,2) not null default 0,
  commission_rate numeric(8,2) not null default 0,
  gst_treatment text not null default 'none'
    check (gst_treatment in ('none', 'inclusive', 'exclusive')),
  gst_rate numeric(8,2) not null default 10,
  commission_ex_gst numeric(12,2) not null default 0,
  gst_amount numeric(12,2) not null default 0,
  commission_payable numeric(12,2) not null default 0,
  notes text,
  bulk_batch_id uuid references commission_tracker.bulk_fee_imports(id),
  upfront_ref text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists commission_tracker.commission_payments (
  id uuid primary key default gen_random_uuid(),
  ledger_id uuid not null references commission_tracker.commission_ledgers(id) on delete cascade,
  internal_payment_id text not null,
  agent_id uuid not null references commission_tracker.agents(id),
  payment_date date not null,
  payment_type text not null default 'Bank transfer'
    check (payment_type in ('Bank transfer', 'Upfront commission')),
  agent_invoice_number text,
  total_amount numeric(12,2) not null default 0,
  selected_months text[] not null default '{}'::text[],
  custom_from_date date,
  custom_to_date date,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists commission_payments_ledger_internal_id_idx
  on commission_tracker.commission_payments(ledger_id, internal_payment_id);

create table if not exists commission_tracker.commission_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references commission_tracker.commission_payments(id) on delete cascade,
  student_id uuid not null references commission_tracker.students(id),
  amount numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists commission_tracker.change_history (
  id uuid primary key default gen_random_uuid(),
  ledger_id uuid references commission_tracker.commission_ledgers(id) on delete cascade,
  changed_at timestamptz not null default now(),
  changed_by uuid references auth.users(id),
  action text not null,
  record_type text not null,
  record_id uuid,
  agent_id uuid references commission_tracker.agents(id),
  student_id uuid references commission_tracker.students(id),
  summary text,
  before_data jsonb,
  after_data jsonb
);

create table if not exists commission_tracker.ledger_snapshots (
  ledger_id uuid primary key references commission_tracker.commission_ledgers(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

grant select, insert, update, delete on all tables in schema commission_tracker to authenticated, service_role;
grant usage, select on all sequences in schema commission_tracker to authenticated, service_role;
create index if not exists fee_collections_agent_date_idx
  on commission_tracker.fee_collections(agent_id, collection_date);

create index if not exists fee_collections_ledger_date_idx
  on commission_tracker.fee_collections(ledger_id, collection_date);

create index if not exists fee_collections_student_idx
  on commission_tracker.fee_collections(student_id);

create index if not exists commission_payments_agent_date_idx
  on commission_tracker.commission_payments(agent_id, payment_date);

create index if not exists commission_payments_ledger_date_idx
  on commission_tracker.commission_payments(ledger_id, payment_date);

create index if not exists change_history_changed_at_idx
  on commission_tracker.change_history(changed_at desc);

create or replace function commission_tracker.can_access_ledger(target_ledger_id uuid)
returns boolean
language sql
security definer
set search_path = commission_tracker
as $$
  select exists (
    select 1
    from commission_tracker.user_profiles profile
    join commission_tracker.user_ledger_access access on access.user_id = profile.id
    where profile.id = auth.uid()
      and profile.status = 'Active'
      and access.ledger_id = target_ledger_id
  );
$$;

create or replace function commission_tracker.has_commission_permission(permission_key text)
returns boolean
language sql
security definer
set search_path = commission_tracker
as $$
  select exists (
    select 1
    from commission_tracker.user_profiles profile
    where profile.id = auth.uid()
      and profile.status = 'Active'
      and permission_key = any(profile.permissions)
  );
$$;

grant execute on all functions in schema commission_tracker to authenticated, service_role;

alter table commission_tracker.commission_ledgers enable row level security;
alter table commission_tracker.user_profiles enable row level security;
alter table commission_tracker.staff_directory enable row level security;
alter table commission_tracker.user_ledger_access enable row level security;
alter table commission_tracker.agents enable row level security;
alter table commission_tracker.students enable row level security;
alter table commission_tracker.bulk_fee_imports enable row level security;
alter table commission_tracker.fee_collections enable row level security;
alter table commission_tracker.commission_payments enable row level security;
alter table commission_tracker.commission_payment_allocations enable row level security;
alter table commission_tracker.change_history enable row level security;
alter table commission_tracker.ledger_snapshots enable row level security;

drop policy if exists "Users can read own profile" on commission_tracker.user_profiles;
create policy "Users can read own profile"
  on commission_tracker.user_profiles for select
  using (id = auth.uid());

drop policy if exists "Users can manage user profiles" on commission_tracker.user_profiles;
create policy "Users can manage user profiles"
  on commission_tracker.user_profiles for all
  using (commission_tracker.has_commission_permission('manageUsers'))
  with check (commission_tracker.has_commission_permission('manageUsers'));

drop policy if exists "Users can read own directory row" on commission_tracker.staff_directory;
create policy "Users can read own directory row"
  on commission_tracker.staff_directory for select
  using (auth_user_id = auth.uid());

drop policy if exists "Managers can manage staff directory" on commission_tracker.staff_directory;
create policy "Managers can manage staff directory"
  on commission_tracker.staff_directory for all
  using (commission_tracker.has_commission_permission('manageUsers'))
  with check (commission_tracker.has_commission_permission('manageUsers'));

drop policy if exists "Users can read own ledger access" on commission_tracker.user_ledger_access;
create policy "Users can read own ledger access"
  on commission_tracker.user_ledger_access for select
  using (user_id = auth.uid());

drop policy if exists "Users can manage ledger access" on commission_tracker.user_ledger_access;
create policy "Users can manage ledger access"
  on commission_tracker.user_ledger_access for all
  using (commission_tracker.has_commission_permission('manageUsers'))
  with check (commission_tracker.has_commission_permission('manageUsers'));

drop policy if exists "Users can view allowed ledgers" on commission_tracker.commission_ledgers;
create policy "Users can view allowed ledgers"
  on commission_tracker.commission_ledgers for select
  using (commission_tracker.can_access_ledger(id));

drop policy if exists "Users can view allowed agents" on commission_tracker.agents;
create policy "Users can view allowed agents"
  on commission_tracker.agents for select
  using (commission_tracker.can_access_ledger(ledger_id));

drop policy if exists "Users can manage allowed agents" on commission_tracker.agents;
create policy "Users can manage allowed agents"
  on commission_tracker.agents for all
  using (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('addAgent')
      or commission_tracker.has_commission_permission('editAgent')
      or commission_tracker.has_commission_permission('disableAgent')
      or commission_tracker.has_commission_permission('deleteAgent')
    )
  )
  with check (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('addAgent')
      or commission_tracker.has_commission_permission('editAgent')
      or commission_tracker.has_commission_permission('disableAgent')
      or commission_tracker.has_commission_permission('deleteAgent')
    )
  );

drop policy if exists "Users can view students" on commission_tracker.students;
create policy "Users can view students"
  on commission_tracker.students for select
  using (commission_tracker.has_commission_permission('viewTracker'));

drop policy if exists "Users can manage students" on commission_tracker.students;
create policy "Users can manage students"
  on commission_tracker.students for all
  using (
    commission_tracker.has_commission_permission('addFee')
    or commission_tracker.has_commission_permission('addBulkFee')
    or commission_tracker.has_commission_permission('addUpfront')
    or commission_tracker.has_commission_permission('editFee')
    or commission_tracker.has_commission_permission('editUpfront')
  )
  with check (
    commission_tracker.has_commission_permission('addFee')
    or commission_tracker.has_commission_permission('addBulkFee')
    or commission_tracker.has_commission_permission('addUpfront')
    or commission_tracker.has_commission_permission('editFee')
    or commission_tracker.has_commission_permission('editUpfront')
  );

drop policy if exists "Users can view allowed fees" on commission_tracker.fee_collections;
create policy "Users can view allowed fees"
  on commission_tracker.fee_collections for select
  using (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('viewTracker'));

drop policy if exists "Users can add allowed fees" on commission_tracker.fee_collections;
create policy "Users can add allowed fees"
  on commission_tracker.fee_collections for insert
  with check (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('addFee')
      or commission_tracker.has_commission_permission('addBulkFee')
      or commission_tracker.has_commission_permission('addUpfront')
      or commission_tracker.has_commission_permission('importFeeCsv')
    )
  );

drop policy if exists "Users can edit allowed fees" on commission_tracker.fee_collections;
create policy "Users can edit allowed fees"
  on commission_tracker.fee_collections for update
  using (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('editFee')
      or commission_tracker.has_commission_permission('editUpfront')
    )
  )
  with check (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('editFee')
      or commission_tracker.has_commission_permission('editUpfront')
    )
  );

drop policy if exists "Users can delete allowed fees" on commission_tracker.fee_collections;
create policy "Users can delete allowed fees"
  on commission_tracker.fee_collections for delete
  using (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('deleteFee')
      or commission_tracker.has_commission_permission('deleteBulk')
      or commission_tracker.has_commission_permission('deleteUpfront')
    )
  );

drop policy if exists "Users can view allowed bulk imports" on commission_tracker.bulk_fee_imports;
create policy "Users can view allowed bulk imports"
  on commission_tracker.bulk_fee_imports for select
  using (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('viewTracker'));

drop policy if exists "Users can add allowed bulk imports" on commission_tracker.bulk_fee_imports;
create policy "Users can add allowed bulk imports"
  on commission_tracker.bulk_fee_imports for insert
  with check (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('addBulkFee'));

drop policy if exists "Users can view allowed commission payments" on commission_tracker.commission_payments;
create policy "Users can view allowed commission payments"
  on commission_tracker.commission_payments for select
  using (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('viewTracker')
      or commission_tracker.has_commission_permission('viewPayCommission')
      or commission_tracker.has_commission_permission('viewInvoices')
      or commission_tracker.has_commission_permission('viewPaidReports')
    )
  );

drop policy if exists "Users can add allowed commission payments" on commission_tracker.commission_payments;
create policy "Users can add allowed commission payments"
  on commission_tracker.commission_payments for insert
  with check (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('payCommission'));

drop policy if exists "Users can edit allowed commission payments" on commission_tracker.commission_payments;
create policy "Users can edit allowed commission payments"
  on commission_tracker.commission_payments for update
  using (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('editCommissionPayment'))
  with check (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('editCommissionPayment'));

drop policy if exists "Users can delete allowed commission payments" on commission_tracker.commission_payments;
create policy "Users can delete allowed commission payments"
  on commission_tracker.commission_payments for delete
  using (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('deleteCommissionPayment'));

drop policy if exists "Users can view allowed allocations" on commission_tracker.commission_payment_allocations;
create policy "Users can view allowed allocations"
  on commission_tracker.commission_payment_allocations for select
  using (
    exists (
      select 1 from commission_tracker.commission_payments payment
      where payment.id = commission_payment_allocations.payment_id
        and commission_tracker.can_access_ledger(payment.ledger_id)
        and (
          commission_tracker.has_commission_permission('viewTracker')
          or commission_tracker.has_commission_permission('viewPayCommission')
          or commission_tracker.has_commission_permission('viewInvoices')
          or commission_tracker.has_commission_permission('viewPaidReports')
        )
    )
  );

drop policy if exists "Users can add allowed allocations" on commission_tracker.commission_payment_allocations;
create policy "Users can add allowed allocations"
  on commission_tracker.commission_payment_allocations for insert
  with check (
    exists (
      select 1 from commission_tracker.commission_payments payment
      where payment.id = commission_payment_allocations.payment_id
        and commission_tracker.can_access_ledger(payment.ledger_id)
        and commission_tracker.has_commission_permission('payCommission')
    )
  );

drop policy if exists "Users can view allowed history" on commission_tracker.change_history;
create policy "Users can view allowed history"
  on commission_tracker.change_history for select
  using (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('viewChangeHistory'));

drop policy if exists "Users can add allowed history" on commission_tracker.change_history;
create policy "Users can add allowed history"
  on commission_tracker.change_history for insert
  with check (commission_tracker.can_access_ledger(ledger_id));

drop policy if exists "Users can view allowed ledger snapshots" on commission_tracker.ledger_snapshots;
create policy "Users can view allowed ledger snapshots"
  on commission_tracker.ledger_snapshots for select
  using (commission_tracker.can_access_ledger(ledger_id) and commission_tracker.has_commission_permission('viewTracker'));

drop policy if exists "Users can save allowed ledger snapshots" on commission_tracker.ledger_snapshots;
create policy "Users can save allowed ledger snapshots"
  on commission_tracker.ledger_snapshots for all
  using (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('addAgent')
      or commission_tracker.has_commission_permission('editAgent')
      or commission_tracker.has_commission_permission('addFee')
      or commission_tracker.has_commission_permission('addBulkFee')
      or commission_tracker.has_commission_permission('editFee')
      or commission_tracker.has_commission_permission('deleteFee')
      or commission_tracker.has_commission_permission('payCommission')
      or commission_tracker.has_commission_permission('editCommissionPayment')
      or commission_tracker.has_commission_permission('deleteCommissionPayment')
      or commission_tracker.has_commission_permission('addUpfront')
      or commission_tracker.has_commission_permission('editUpfront')
      or commission_tracker.has_commission_permission('deleteUpfront')
      or commission_tracker.has_commission_permission('manageUsers')
    )
  )
  with check (
    commission_tracker.can_access_ledger(ledger_id)
    and (
      commission_tracker.has_commission_permission('addAgent')
      or commission_tracker.has_commission_permission('editAgent')
      or commission_tracker.has_commission_permission('addFee')
      or commission_tracker.has_commission_permission('addBulkFee')
      or commission_tracker.has_commission_permission('editFee')
      or commission_tracker.has_commission_permission('deleteFee')
      or commission_tracker.has_commission_permission('payCommission')
      or commission_tracker.has_commission_permission('editCommissionPayment')
      or commission_tracker.has_commission_permission('deleteCommissionPayment')
      or commission_tracker.has_commission_permission('addUpfront')
      or commission_tracker.has_commission_permission('editUpfront')
      or commission_tracker.has_commission_permission('deleteUpfront')
      or commission_tracker.has_commission_permission('manageUsers')
    )
  );

-- First admin setup note:
-- 1. Create the first user in Supabase Auth.
-- 2. Copy that Auth user id.
-- 3. Insert one user_profiles row with permissions such as:
--    '{viewTracker,viewDashboard,viewAgentsList,viewAgentPortal,viewChangeHistory,addAgent,editAgent,disableAgent,deleteAgent,viewAgentGst,addFee,addBulkFee,editFee,deleteFee,deleteBulk,openBulk,importFeeCsv,viewPayCommission,payCommission,payClaimBack,editCommissionPayment,deleteCommissionPayment,updateInvoice,viewInvoices,addUpfront,editUpfront,deleteUpfront,viewReports,viewFeesReports,viewCommissionReports,viewPaidReports,viewBalanceReports,viewStudentReports,viewActualSummary,exportReports,revertChanges,resetLedger,downloadBackup,importBackup,manageUsers}'
-- 4. Insert user_ledger_access rows for Trial and SHIC.

