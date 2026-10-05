insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('order-documents', 'order-documents', false, 10485760,
        array['application/pdf', 'image/png', 'image/jpeg'])
on conflict (id) do nothing;

create function private.safe_uuid(value text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return value::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

grant execute on function private.safe_uuid(text) to authenticated;

create policy order_documents_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'order-documents'
    and private.is_org_member(private.safe_uuid((storage.foldername(name))[1]))
  );

create policy order_documents_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'order-documents'
    and private.has_org_role(
      private.safe_uuid((storage.foldername(name))[1]),
      array['owner', 'operator']::public.member_role[]
    )
  );

create policy order_documents_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'order-documents'
    and private.has_org_role(
      private.safe_uuid((storage.foldername(name))[1]),
      array['owner', 'operator']::public.member_role[]
    )
  );

create policy order_documents_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'order-documents'
    and private.has_org_role(
      private.safe_uuid((storage.foldername(name))[1]),
      array['owner']::public.member_role[]
    )
  );
