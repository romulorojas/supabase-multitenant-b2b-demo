create function public.process_payment_webhook(
  p_provider text,
  p_event_id text,
  p_order_id uuid,
  p_event_type text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
begin
  insert into public.processed_webhooks (provider, external_event_id)
  values (p_provider, p_event_id)
  on conflict do nothing;

  if not found then
    return false;
  end if;

  select organization_id into v_org from public.orders where id = p_order_id for update;
  if v_org is null then
    raise exception 'order % not found', p_order_id using errcode = 'P0002';
  end if;

  if p_event_type = 'payment.succeeded' then
    update public.orders set status = 'confirmed'
    where id = p_order_id and status = 'draft';
  end if;

  insert into public.order_events (organization_id, order_id, event_type, payload)
  values (v_org, p_order_id, 'webhook.' || p_event_type,
          jsonb_build_object('provider', p_provider, 'event_id', p_event_id));

  return true;
end;
$$;

revoke all on function public.process_payment_webhook(text, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.process_payment_webhook(text, text, uuid, text) to service_role;
