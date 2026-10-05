# Tests

pgTAP tests executed by the Supabase CLI against the local database.

```bash
npx supabase start
npm test
```

| File | Covers |
|------|--------|
| `rls.sql` | Tenant isolation, role permissions, anonymous access, deactivated members |
| `permissions.sql` | RLS enabled on every table, grants on privileged functions, webhook idempotency |

Each test runs inside a transaction that is rolled back, so the seed data is left untouched.
