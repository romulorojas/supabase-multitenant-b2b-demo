# Security decisions

| Decision | Reason |
|----------|--------|
| Authorization in policies, not in application code | Every client path, including ad-hoc API calls, goes through the same checks |
| Tenant derived from membership, never trusted from input | A client can send any `organization_id`; policies verify it against `organization_members` |
| User-scoped client inside `create-order` | Keeps RLS in force; no privileged path for user-originated writes |
| `service_role` only in the webhook function | Webhooks have no user identity; the function is the trust boundary and authenticates by signature |
| HMAC with timestamp window | Prevents forgery and replay of captured requests |
| Idempotency key in the same transaction as the side effect | A retry after a partial failure cannot lose or double-apply an event |
| Constant-time signature comparison | Avoids timing leaks |
| `security definer` functions pin `search_path` | Prevents object shadowing |
| Helpers in an unexposed `private` schema | Not callable through the API |
| Soft deactivation of members | Immediate revocation with history preserved |
| Private storage bucket with MIME and size limits | Documents are only reachable through policies |
| Webhook function does not echo internal errors | Error codes are logged server-side only |

## Secrets

`.env` files are ignored. `.env.example` lists variable names only. The local keys printed by `supabase start` are public defaults and are not valid outside a local stack.
