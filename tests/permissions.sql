begin;
select plan(10);

select ok((select relrowsecurity from pg_class where oid = 'public.organizations'::regclass), 'rls enabled on organizations');
select ok((select relrowsecurity from pg_class where oid = 'public.organization_members'::regclass), 'rls enabled on organization_members');
select ok((select relrowsecurity from pg_class where oid = 'public.orders'::regclass), 'rls enabled on orders');
select ok((select relrowsecurity from pg_class where oid = 'public.order_events'::regclass), 'rls enabled on order_events');
select ok((select relrowsecurity from pg_class where oid = 'public.processed_webhooks'::regclass), 'rls enabled on processed_webhooks');

select ok(not has_table_privilege('authenticated', 'public.processed_webhooks', 'select'), 'processed_webhooks closed to authenticated');
select ok(not has_function_privilege('authenticated', 'public.process_payment_webhook(text,text,uuid,text)', 'execute'), 'webhook processor closed to authenticated');
select ok(has_function_privilege('service_role', 'public.process_payment_webhook(text,text,uuid,text)', 'execute'), 'webhook processor open to service_role');
select ok(not has_schema_privilege('anon', 'private', 'usage'), 'private schema closed to anon');

select is(
  public.process_payment_webhook('stripe', 'evt_1', '00a00000-0000-0000-0000-000000000003', 'payment.succeeded')
  and not public.process_payment_webhook('stripe', 'evt_1', '00a00000-0000-0000-0000-000000000003', 'payment.succeeded'),
  true, 'duplicate webhook event is rejected');

select * from finish();
rollback;
