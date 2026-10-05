# RLS model

## Helpers

```sql
private.is_org_member(org uuid) returns boolean
private.has_org_role(org uuid, roles member_role[]) returns boolean
```

Both are `security definer` with an empty `search_path`, `stable`, and read `organization_members` filtered by `auth.uid()` and `active`. `auth.uid()` is wrapped in a subselect so the planner evaluates it once per statement.

They run with the owner's privileges so policies on `organization_members` itself can use them without recursing. The `private` schema is not exposed by the API and `anon` has no usage on it.

## Policy matrix

| Table | select | insert | update | delete |
|-------|--------|--------|--------|--------|
| organizations | member | none | owner | none |
| organization_members | self or member of same org | owner | owner | owner |
| orders | member | owner, operator | owner, operator | owner |
| order_events | member | none (trigger) | none | none |
| processed_webhooks | none | none | none | none |
| storage.objects (`order-documents`) | member | owner, operator | owner, operator | owner |

## Defense in depth

- Table grants are revoked and re-granted per column where it matters, so `orders.organization_id` and `created_by` cannot be updated even by a role allowed to update the row.
- `orders_before_write` rejects changes to those columns and maintains `updated_at`.
- Creating an organization is not exposed to clients; tenant provisioning is an administrative operation.

## Testing

`tests/rls.sql` switches role and JWT claims inside a transaction and asserts visible row counts and error codes. `tests/permissions.sql` asserts structural properties: RLS enabled everywhere, privileges on the webhook processor, idempotency.
