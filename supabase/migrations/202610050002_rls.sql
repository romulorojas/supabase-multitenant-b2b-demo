create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create function private.is_org_member(target_organization_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.organization_id = target_organization_id
      and m.user_id = (select auth.uid())
      and m.active
  );
$$;

create function private.has_org_role(
  target_organization_id uuid,
  allowed_roles public.member_role[]
)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.organization_id = target_organization_id
      and m.user_id = (select auth.uid())
      and m.active
      and m.role = any (allowed_roles)
  );
$$;

revoke all on function private.is_org_member(uuid) from public;
revoke all on function private.has_org_role(uuid, public.member_role[]) from public;
grant execute on function private.is_org_member(uuid) to authenticated;
grant execute on function private.has_org_role(uuid, public.member_role[]) to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.orders enable row level security;
alter table public.order_events enable row level security;
alter table public.processed_webhooks enable row level security;

revoke all on all tables in schema public from anon, authenticated;
grant select on public.organizations, public.organization_members, public.order_events to authenticated;
grant update (name) on public.organizations to authenticated;
grant insert, update, delete on public.organization_members to authenticated;
grant select, delete on public.orders to authenticated;
grant insert (organization_id, external_reference, customer_name, status, amount,
              pickup_lat, pickup_lng, created_by) on public.orders to authenticated;
grant update (external_reference, customer_name, status, amount, pickup_lat, pickup_lng)
  on public.orders to authenticated;

create policy organizations_select on public.organizations
  for select to authenticated
  using (private.is_org_member(id));

create policy organizations_update on public.organizations
  for update to authenticated
  using (private.has_org_role(id, array['owner']::public.member_role[]))
  with check (private.has_org_role(id, array['owner']::public.member_role[]));

create policy members_select on public.organization_members
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_org_member(organization_id));

create policy members_insert on public.organization_members
  for insert to authenticated
  with check (private.has_org_role(organization_id, array['owner']::public.member_role[]));

create policy members_update on public.organization_members
  for update to authenticated
  using (private.has_org_role(organization_id, array['owner']::public.member_role[]))
  with check (private.has_org_role(organization_id, array['owner']::public.member_role[]));

create policy members_delete on public.organization_members
  for delete to authenticated
  using (private.has_org_role(organization_id, array['owner']::public.member_role[]));

create policy orders_select on public.orders
  for select to authenticated
  using (private.is_org_member(organization_id));

create policy orders_insert on public.orders
  for insert to authenticated
  with check (
    private.has_org_role(organization_id, array['owner', 'operator']::public.member_role[])
    and created_by = (select auth.uid())
  );

create policy orders_update on public.orders
  for update to authenticated
  using (private.has_org_role(organization_id, array['owner', 'operator']::public.member_role[]))
  with check (private.has_org_role(organization_id, array['owner', 'operator']::public.member_role[]));

create policy orders_delete on public.orders
  for delete to authenticated
  using (private.has_org_role(organization_id, array['owner']::public.member_role[]));

create policy order_events_select on public.order_events
  for select to authenticated
  using (private.is_org_member(organization_id));
