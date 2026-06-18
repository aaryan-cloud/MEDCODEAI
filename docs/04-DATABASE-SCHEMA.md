# MedCode AI — Database Schema

> Full DDL: [`backend/db/schema_v3.sql`](../backend/db/schema_v3.sql) (PostgreSQL 16).
> Today the app uses SQLite with only `users` + `payments`. This is the target production model.

## 1. Entity overview

```
organizations 1───∞ users 1───∞ user_roles
      │                  │
      │                  ├──∞ refresh_tokens
      │                  └──∞ notifications
      │
      ├──∞ patients 1───∞ cases 1───∞ documents 1───∞ extractions
      │                     │                              │
      │                     │                              └─ structured JSONB (+provenance)
      │                     ├──∞ coding_results 1───∞ coded_items ──▶ icd10_codes (FK-by-value)
      │                     └──∞ reviews
      │
      ├──∞ consents          ├── retention_policies (1:1)
      ├──∞ usage_events      └──∞ audit_events (append-only)
```

## 2. Table-by-table (why it exists)

| Table | Purpose | Key columns |
|---|---|---|
| `organizations` | Tenant root; plan, quota, data region | `plan`, `data_region`, `monthly_doc_quota` |
| `users` | Members of an org; auth + lockout | `org_id`, `email`, `locked_until`, `mfa_secret` |
| `user_roles` | RBAC (multi-role per user) | `role` enum |
| `refresh_tokens` | Token revocation/rotation | `jti`, `token_hash`, `revoked_at` |
| `patients` | Minimal patient identity (PHI) | `mrn`, `dob` |
| `cases` | Unit of work; workflow status + assignment | `status`, `assigned_coder`, `assigned_reviewer` |
| `documents` | Uploaded files; AV + integrity | `storage_key`, `content_sha256`, `status` |
| `extractions` | OCR output + confidence + provenance | `raw_text`, `structured`, `confidence_map` |
| `coding_results` | One coding run per document/extraction | `coder_review_required`, `all_verified`, `latency_ms` |
| `coded_items` | Each ICD-10 code w/ evidence + review flags | `code`, `relationship`, `evidence_span`, `accepted` |
| `icd10_codes` | **Verified reference set** (anti-hallucination) | `code`, `keywords`, `search_tsv` |
| `reviews` | HITL decisions, corrections, e-sign | `decision`, `corrections`, `signature_hash` |
| `notifications` | In-app/email events | `type`, `read_at` |
| `audit_events` | Immutable access/action log | `action`, `phi_accessed`, INSERT-only |
| `consents` | Patient/data-principal consent | `purpose`, `status` |
| `retention_policies` | Per-org retention + auto-purge | `document_days`, `auto_purge` |
| `usage_events` | Metering for billing/quotas | `kind`, `quantity` |

## 3. Workflow state machine (`cases.status` / `documents.status`)

```
uploaded → scanning → extracted → ready_for_coding → coding → coded
                                                          │
                              coder_review_required? ─────┤
                                                          ▼
                                                     in_review ──▶ approved ──▶ finalized ──▶ exported
                                                          └──────▶ rejected ──▶ (back to coding)
   any stage ──▶ failed (with error + retry)
```

## 4. Anti-hallucination invariant (enforced in DB + app)
- `coded_items.code` is only persisted if it exists in `icd10_codes` (`verified = true`). The app rejects/flags any code not found (mirrors current `llm_service._parse_and_validate`).
- A nightly job can add a CHECK/trigger: refuse insert of a `coded_items.code` absent from `icd10_codes` unless `added_by_human = true` (a human override is auditable).

## 5. Tenancy / RLS
Every PHI table has `org_id` and `ENABLE ROW LEVEL SECURITY` with policy
`org_id = current_setting('app.current_org')::uuid`. The API sets
`SET app.current_org = :org` after authenticating each request, so a query bug
cannot leak across tenants.

## 6. Indexing highlights
- `cases(org_id, status)` and `cases(assigned_coder)` — queue views.
- `documents(case_id)`, `extractions(document_id)`, `coded_items(coding_result_id)` — joins.
- `icd10_codes` GIN on `search_tsv` (full-text) + `gin_trgm_ops` (fuzzy) + optional `pgvector` for hybrid retrieval at 74k codes.
- Partial index `notifications(user_id) WHERE read_at IS NULL` — unread badges.

## 7. Migration from current SQLite
1. Stand up Postgres + Alembic baseline = `schema_v3.sql`.
2. Backfill `organizations` (one per existing customer), attach existing `users` with a default `org_id` and `coder`/`org_admin` roles.
3. Migrate `payments` → `usage_events` + a `subscriptions` table (add when billing is built out).
4. Load `data/icd10_data.py` into `icd10_codes`, compute `search_tsv` and embeddings.
