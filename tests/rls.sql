begin;
select plan(19);

create function public.t_affected(q text) returns int language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  return n;
end$$;
grant execute on function public.t_affected(text) to authenticated;

-- Alpha owner
reset role;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.orders), 3, 'alpha owner sees only alpha orders');
select is((select count(*)::int from public.orders where organization_id = '0b000000-0000-0000-0000-000000000001'), 0, 'alpha owner sees no beta orders');
select is((select count(*)::int from public.organizations), 1, 'alpha owner sees only its organization');
select is((select count(*)::int from public.orders where id = '00b00000-0000-0000-0000-000000000001'), 0, 'known beta order id returns nothing');

-- Alpha operator
reset role;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.orders), 3, 'alpha operator sees alpha orders');
select lives_ok(
  $$insert into public.orders (organization_id, customer_name, amount, created_by)
    values ('0a000000-0000-0000-0000-000000000001', 'Nuevo Cliente', 1000, 'a1000000-0000-0000-0000-000000000002')$$,
  'alpha operator creates an alpha order');
select throws_ok(
  $$insert into public.orders (organization_id, customer_name, amount, created_by)
    values ('0b000000-0000-0000-0000-000000000001', 'Intruso', 1000, 'a1000000-0000-0000-0000-000000000002')$$,
  '42501', null, 'alpha operator cannot create a beta order');
select throws_ok(
  $$insert into public.orders (organization_id, customer_name, amount, created_by)
    values ('0a000000-0000-0000-0000-000000000001', 'Suplantación', 1000, 'a1000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'created_by must match the caller');
select is(
  public.t_affected($$update public.orders set status = 'in_progress' where id = '00a00000-0000-0000-0000-000000000003'$$),
  1, 'alpha operator updates an alpha order');
select is(
  public.t_affected($$update public.orders set status = 'cancelled' where id = '00b00000-0000-0000-0000-000000000001'$$),
  0, 'alpha operator cannot update a beta order');
select throws_ok(
  $$update public.orders set organization_id = '0b000000-0000-0000-0000-000000000001' where id = '00a00000-0000-0000-0000-000000000001'$$,
  '42501', null, 'organization_id cannot be reassigned');
select is(
  public.t_affected($$delete from public.orders where id = '00a00000-0000-0000-0000-000000000001'$$),
  0, 'alpha operator cannot delete orders');

-- Alpha viewer
reset role;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.orders where organization_id = '0a000000-0000-0000-0000-000000000001'), 4, 'alpha viewer sees alpha orders');
select is(
  public.t_affected($$update public.orders set status = 'cancelled' where organization_id = '0a000000-0000-0000-0000-000000000001'$$),
  0, 'alpha viewer cannot update orders');
select throws_ok(
  $$insert into public.orders (organization_id, customer_name, amount, created_by)
    values ('0a000000-0000-0000-0000-000000000001', 'Viewer', 1, 'a1000000-0000-0000-0000-000000000003')$$,
  '42501', null, 'alpha viewer cannot create orders');
select is((select count(*)::int from public.order_events where organization_id = '0b000000-0000-0000-0000-000000000001'), 0, 'alpha viewer sees no beta events');

-- Anonymous
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;

select throws_ok('select count(*) from public.orders', '42501', null, 'anon cannot read orders');
select throws_ok('select count(*) from public.organization_members', '42501', null, 'anon cannot read memberships');

-- Deactivated member
reset role;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
update public.organization_members set active = false
  where organization_id = '0a000000-0000-0000-0000-000000000001' and user_id = 'a1000000-0000-0000-0000-000000000002';

reset role;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.orders), 0, 'deactivated member loses read access');

reset role;
select * from finish();
rollback;
