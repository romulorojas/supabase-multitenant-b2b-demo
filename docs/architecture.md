# Architecture

## Components

- **PostgreSQL** is the source of truth and the authorization layer.
- **Supabase Auth** issues the JWT; `auth.uid()` identifies the caller inside policies.
- **PostgREST** exposes `public` tables. Every request runs as `anon` or `authenticated` and is subject to RLS.
- **Edge Functions** cover what plain table access cannot: payload validation for user-facing writes and signed inbound integrations.
- **Realtime** streams row changes filtered by the same RLS policies.
- **Storage** reuses the membership helpers for object-level access.

## Request flows

### Client read

1. Client calls the API with its JWT.
2. PostgREST switches to the `authenticated` role and sets the JWT claims.
3. `orders_select` calls `private.is_org_member(organization_id)`.
4. Only rows from active memberships are returned.

### Order creation

1. Client calls `create-order` with its JWT.
2. The function validates the token and payload.
3. It inserts through a client holding the caller's token. `orders_insert` checks role and `created_by`.
4. `orders_audit` writes an `order.created` event, which Realtime delivers to subscribers.

### Webhook

1. Provider posts a signed event to `external-webhook`.
2. The function verifies timestamp and HMAC.
3. `process_payment_webhook` inserts into `processed_webhooks`; on conflict the call returns `false` and nothing else runs.
4. Otherwise the order is updated and an event is recorded, all in one transaction.

## Migrations

| File | Content |
|------|---------|
| `202610050001_initial_schema.sql` | Tables, indexes, triggers |
| `202610050002_rls.sql` | Helpers, grants, policies |
| `202610050003_storage.sql` | Bucket and storage policies |
| `202610050004_realtime.sql` | Realtime publication |
| `202610050005_webhooks.sql` | Idempotent webhook processor |
