# MedCode AI — Full System Architecture

## 1. Architectural principles
1. **API-first** — every capability is a documented REST endpoint; UI is just a client.
2. **Multi-tenant by default** — every row is scoped to an `org_id`; isolation enforced in the data layer.
3. **Async for slow work** — OCR + LLM run in background workers, never inside the request thread.
4. **PHI minimization** — only structured, de-identified-where-possible context reaches the LLM.
5. **Everything auditable** — all PHI access and state changes emit immutable audit events.
6. **Stateless services** — horizontal scale behind a load balancer; state in Postgres/Redis/object store.

## 2. Target component diagram

```
                         ┌──────────────┐
                         │  Web client  │ (React SPA)
                         └──────┬───────┘
                                │ HTTPS (TLS 1.2+)
                         ┌──────▼───────┐
                         │ CDN + WAF +  │  rate limit, bot/DDoS, TLS term
                         │ API Gateway  │
                         └──────┬───────┘
                                │
                ┌───────────────▼────────────────┐
                │        API service (FastAPI)    │  auth, RBAC, tenancy,
                │   stateless, N replicas         │  validation, orchestration
                └───┬───────┬──────────┬──────────┘
                    │       │          │
        enqueue ┌───▼──┐ ┌──▼───┐  ┌───▼────────┐
                │Redis │ │Postgres│ │ Object store│ (S3/MinIO, SSE-KMS)
                │queue │ │ (RLS)  │ │ encrypted   │  raw docs, page imgs
                └──┬───┘ └────────┘ └─────────────┘
                   │
         ┌─────────▼──────────┐
         │  Worker pool       │  Celery/Arq
         │  - extract (OCR)   │
         │  - nlp+code        │  ┌────────────┐   ┌──────────────┐
         │  - notify/export   │─▶│ ICD index  │   │ LLM provider │
         └─────────┬──────────┘  │ (BM25/     │   │ (BAA-covered │
                   │             │  pgvector) │   │  or on-prem) │
                   │             └────────────┘   └──────────────┘
         ┌─────────▼──────────────────────────────────────────────┐
         │ Observability: logs (Loki) · metrics (Prometheus) ·     │
         │ traces (OTel) · errors (Sentry) · audit sink (WORM)     │
         └─────────────────────────────────────────────────────────┘
```

## 3. Request → result lifecycle (a coding job)

```
1. POST /api/cases                         → create case (org-scoped)
2. POST /api/cases/{id}/documents          → presigned upload; AV scan; status=UPLOADED
3. worker: extract                          → OCR pipeline → status=EXTRACTED (+confidence)
4. (optional) human correction              → PATCH extraction → status=READY_FOR_CODING
5. worker: code                             → NLP → build minimized context → BM25 candidates
                                              → constrained LLM → DB-validate → persist coding_result
                                              → if conf<τ: coder_review_required=true, status=IN_REVIEW
                                                else status=CODED
6. reviewer: approve/reject/correct         → status=APPROVED → FINALIZED (locked, signed)
7. export: FHIR / 837 / CSV / PDF           → status=EXPORTED
   every step writes an audit_event
```

## 4. Technology choices (recommended)

| Concern | Choice | Why |
|---|---|---|
| API framework | **FastAPI** (migrate from Flask) | async, typed, OpenAPI out of the box; keep Flask only if time-boxed |
| DB | **PostgreSQL 16** + Row-Level Security | tenancy isolation, JSONB for results, mature |
| Migrations | **Alembic** | versioned schema |
| Cache/queue | **Redis** + **Celery** (or Arq) | async OCR/LLM, rate limiting, sessions |
| Object storage | **S3 / MinIO** w/ SSE-KMS | encrypted PHI documents |
| Search/retrieval | BM25 now → **pgvector hybrid** (BM25 + embeddings) | better recall at 74k codes |
| AuthZ | RBAC + Postgres RLS | defense in depth |
| Secrets | **Vault / cloud KMS / Secrets Manager** | no secrets in env files |
| Containers | **Docker** + **Kubernetes/Helm** | scale, on-prem & VPC deploys |
| Observability | Prometheus + Grafana + Loki + OTel + Sentry | SRE-grade |
| IaC | **Terraform** | reproducible environments |

## 5. Environments
`local` → `dev` → `staging` (PHI-free synthetic) → `prod`. Optional **single-tenant VPC / on-prem** profile (Helm values) for hospitals that won't use shared SaaS.

## 6. Tenancy & isolation
- Every PHI table has `org_id NOT NULL`.
- Postgres **RLS policy** `org_id = current_setting('app.current_org')::uuid`; API sets the GUC per request after auth.
- Object-store keys prefixed `org/{org_id}/...`; per-tenant KMS data keys for stricter isolation tiers.
- Optional **dedicated-DB-per-tenant** for enterprise contracts.

## 7. Scalability notes
- API and workers scale horizontally (stateless). Separate worker queues for `extract` (CPU/GPU heavy) and `code` (IO/LLM heavy) so one doesn't starve the other.
- LLM and OCR are the latency/cost bottlenecks → cache by document content-hash; batch where possible; circuit-breaker + retry with backoff on provider errors.
- ICD index loaded once per worker (as today via singleton), rebuilt on code-set updates.

## 8. Migration path from the current Flask app
The existing `app.py`/services are reusable as the **coding core**. Steps:
1. Wrap services behind a job interface; move OCR/LLM calls into workers.
2. Introduce Postgres + the schema in `04-DATABASE-SCHEMA.md`; persist every stage.
3. Add RBAC/tenancy middleware; replace hand-rolled JWT with `PyJWT`/`Authlib` + refresh/revocation.
4. Keep BM25 `icd_service` and constrained `llm_service` logic intact — they are the crown jewels.
