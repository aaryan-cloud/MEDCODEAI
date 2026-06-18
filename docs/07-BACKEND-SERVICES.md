# MedCode AI — Backend Services

## 1. Service map (target)

```
api/                      # FastAPI app (HTTP only; thin)
  routers/                #   auth, orgs, cases, documents, coding, review, export, admin
  middleware/             #   auth, tenancy(RLS GUC), rate-limit, request-id, audit
  schemas/                #   pydantic request/response models
core/
  auth_service            # JWT(access+refresh), revocation, MFA, password policy   ← replaces auth.py
  rbac_service            # role/permission checks
  tenancy                 # org context + RLS binding
  audit_service           # emit immutable audit_events
domain/
  ocr_service       [H]   # backend/services/ocr_service.py  (move to worker)
  nlp_service       [H]   # backend/services/medical_nlp.py  + negation/temporal
  icd_service       [H]   # backend/services/icd_service.py  (BM25 → hybrid)
  coding_service    [H]   # backend/services/llm_service.py  (constrained LLM + validate)
  drug_service      [H]   # interaction rules (→ licensed source)
  phi_minimizer     [N]   # build LLM context from structured fields ONLY
  review_service    [N]   # HITL state machine
  export_service    [H/N] # report_service.py + FHIR/X12/CSV
  notification_svc  [N]
workers/                  # Celery/Arq tasks: extract, code, notify, export, purge
infra/
  db (SQLAlchemy+Alembic), storage (S3/MinIO), cache (Redis), llm_client, av_scanner
```

## 2. Reuse vs replace

| Current file | Verdict | Action |
|---|---|---|
| `services/llm_service.py` | **Keep — crown jewel** | Extract `phi_minimizer`; stop sending `text[:3000]`; move to worker; add retries/circuit-breaker; record `latency_ms`, `model`, `candidate_count`. |
| `services/icd_service.py` | **Keep** | Back with `icd10_codes` table; add hybrid BM25+vector; persist scores. |
| `services/medical_nlp.py` | **Keep + extend** | Add negation, temporal, abbreviation expansion; emit char offsets for evidence spans. |
| `services/ocr_service.py` | **Keep + upgrade** | See `02-OCR-ARCHITECTURE.md`; run async; per-token confidence; tables; correction write-back. |
| `auth.py` | **Replace hand-rolled JWT** | `PyJWT`/Authlib, refresh+revocation, RBAC, lockout, MFA; keep PBKDF2/bcrypt hashing. |
| `payment.py` | **Keep, extend** | Add plans/quotas, usage metering, invoices. |
| `report_service.py`, `email_service.py` | **Keep** | Move email to a worker; add FHIR/X12 exporters. |
| `app.py` | **Refactor** | Split monolith routes into routers; add middleware stack. |

## 3. PHI minimizer (new — compliance-critical)
Today `coding_service.analyze(text, entities, candidates)` passes raw `text[:3000]`.
Target: the LLM receives **only** the structured clinical summary
(`_build_clinical_summary` already exists) + candidate codes — never the raw document.
If raw context is ever required for ambiguous cases, it must be **de-identified**
(strip names/MRN/dates/contact via the NLP demographic detector) and gated by config
`ALLOW_RAW_LLM_CONTEXT=false` by default. This single change is what makes the
"we don't send raw patient documents to the LLM" claim true.

## 4. Async job model
- `extract`, `code`, `export`, `notify`, `purge` are Celery tasks with idempotency keys,
  exponential-backoff retries (matching the request guidance), and dead-letter handling.
- Job status persisted on `documents.status` / `cases.status`; surfaced via polling + webhooks.
- Separate queues for CPU-heavy OCR and IO/LLM-heavy coding.

## 5. Reliability patterns
- **Retry/backoff** around LLM + OCR + email + storage.
- **Circuit breaker** + fallback (current `_fallback_result` BM25 path is a good pattern — keep, but mark results `coder_review_required=true`).
- **Idempotency** on uploads/coding to avoid double-charging quota.
- **Graceful degradation:** if LLM down, return BM25 candidates flagged for mandatory human coding rather than failing the case.

## 6. Config & secrets
All secrets from a vault/secret manager, never `.env` in the image. Fail closed: refuse
to boot if `JWT_SECRET` is the default placeholder (today it silently falls back — fix).
