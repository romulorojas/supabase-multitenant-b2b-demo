insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
select
  '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
  extensions.crypt('password123', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}', jsonb_build_object('name', u.name), now(), now(),
  '', '', '', ''
from (values
  ('a1000000-0000-0000-0000-000000000001'::uuid, 'alice@alpha.test', 'Alice'),
  ('a1000000-0000-0000-0000-000000000002'::uuid, 'carlos@alpha.test', 'Carlos'),
  ('a1000000-0000-0000-0000-000000000003'::uuid, 'pedro@alpha.test', 'Pedro'),
  ('b1000000-0000-0000-0000-000000000001'::uuid, 'laura@beta.test', 'Laura')
) as u(id, email, name);

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       now(), now(), now()
from auth.users u;

insert into public.organizations (id, name) values
  ('0a000000-0000-0000-0000-000000000001', 'Organization Alpha'),
  ('0b000000-0000-0000-0000-000000000001', 'Organization Beta');

insert into public.organization_members (organization_id, user_id, role) values
  ('0a000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'owner'),
  ('0a000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002', 'operator'),
  ('0a000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000003', 'viewer'),
  ('0b000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'owner');

insert into public.orders (id, organization_id, external_reference, customer_name, status, amount, pickup_lat, pickup_lng, created_by) values
  ('00a00000-0000-0000-0000-000000000001', '0a000000-0000-0000-0000-000000000001', 'ALP-1001', 'Distribuidora Norte', 'confirmed', 125000.00, -33.448900, -70.669300, 'a1000000-0000-0000-0000-000000000001'),
  ('00a00000-0000-0000-0000-000000000002', '0a000000-0000-0000-0000-000000000001', 'ALP-1002', 'Ferretería Central', 'in_progress', 48900.50, -33.437800, -70.650400, 'a1000000-0000-0000-0000-000000000002'),
  ('00a00000-0000-0000-0000-000000000003', '0a000000-0000-0000-0000-000000000001', 'ALP-1003', 'Café del Valle', 'draft', 15000.00, null, null, 'a1000000-0000-0000-0000-000000000002'),
  ('00b00000-0000-0000-0000-000000000001', '0b000000-0000-0000-0000-000000000001', 'BET-2001', 'Textiles Sur', 'completed', 310000.00, -36.826900, -73.049800, 'b1000000-0000-0000-0000-000000000001'),
  ('00b00000-0000-0000-0000-000000000002', '0b000000-0000-0000-0000-000000000001', 'BET-2002', 'Librería Austral', 'draft', 22500.00, null, null, 'b1000000-0000-0000-0000-000000000001');
