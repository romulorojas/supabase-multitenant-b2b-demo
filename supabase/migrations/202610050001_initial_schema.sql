create type public.member_role as enum ('owner', 'operator', 'viewer');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null default 'viewer',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  external_reference text,
  customer_name text not null,
  status text not null default 'draft'
    check (status in ('draft', 'confirmed', 'in_progress', 'completed', 'cancelled')),
  amount numeric(12,2) not null check (amount >= 0),
  pickup_lat numeric(9,6) check (pickup_lat between -90 and 90),
  pickup_lng numeric(9,6) check (pickup_lng between -180 and 180),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.processed_webhooks (
  provider text not null,
  external_event_id text not null,
  processed_at timestamptz not null default now(),
  primary key (provider, external_event_id)
);

create index orders_organization_idx on public.orders (organization_id, created_at desc);
create index orders_external_reference_idx on public.orders (organization_id, external_reference)
  where external_reference is not null;
create index members_user_idx on public.organization_members (user_id) where active;
create index order_events_order_idx on public.order_events (order_id, created_at);

create function public.orders_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.organization_id <> old.organization_id or new.created_by <> old.created_by then
      raise exception 'organization_id and created_by are immutable';
    end if;
  end if;
  new.updated_at = now();
  return new;
end;
$$;

create trigger orders_before_write
before insert or update on public.orders
for each row execute function public.orders_before_write();

create function public.orders_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_events (organization_id, order_id, event_type, payload, created_by)
    values (new.organization_id, new.id, 'order.created',
            jsonb_build_object('status', new.status, 'amount', new.amount), auth.uid());
  elsif new.status is distinct from old.status then
    insert into public.order_events (organization_id, order_id, event_type, payload, created_by)
    values (new.organization_id, new.id, 'order.status_changed',
            jsonb_build_object('from', old.status, 'to', new.status), auth.uid());
  end if;
  return new;
end;
$$;

create trigger orders_audit
after insert or update on public.orders
for each row execute function public.orders_audit();
