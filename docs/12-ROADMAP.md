# MedCode AI — Roadmap: Prototype → Official Launch

Assumes ~4–6 engineers. Timeline indicative; sequence matters more than dates.

## Phase 0 — Stop the bleeding (Week 1–2) · *Security hygiene*
- Rotate every leaked secret; move to secret manager; secret-scan in CI.
- Replace hand-rolled JWT with vetted lib + refresh + revocation; fail-closed on default secret.
- Lock CORS; add rate limiting; security headers.
- AV scan + allow-list + size cap on uploads.
**Exit:** no known critical security holes; safe to onboard internal testers.

## Phase 1 — Persistence, tenancy & RBAC (Week 3–8) · *Become a real multi-user app*
- Postgres + Alembic; apply `schema_v3.sql`; load `icd10_codes`.
- Organizations + users + roles; RLS tenant isolation.
- Persist cases/documents/extractions/coding_results/coded_items (kill stateless analyze-only).
- Audit log + activity timeline.
- Object storage (encrypted) for documents.
**Exit:** a coder in Org A can upload, code, and revisit cases; Org B can't see them; every action audited.

## Phase 2 — Async pipeline & HITL workflow (Week 9–14) · *The clinical workflow*
- Redis + Celery workers; `extract`/`code` async; document queue; retry/backoff; idempotency.
- OCR v2 (deskew/denoise/orientation/tables, per-token confidence, correction write-back).
- Review state machine + reviewer queue + corrections + e-sign + lock.
- Confidence-based routing (`coder_review_required`).
- Notifications (in-app + email); batch upload.
- Replace mock frontend dashboards with API-backed pages; evidence-highlight view.
**Exit:** end-to-end "upload → extract → correct → code → review → approve → export" works for real.

## Phase 3 — Compliance & PHI safety (Week 12–18, overlaps) · *Sellable to hospitals*
- PHI minimizer enforced; BAA-covered or self-hosted LLM.
- Encryption at rest verified; KMS; per-tenant keys (enterprise tier).
- Consent workflow; retention/erasure scheduler; data-principal rights.
- Policies, risk assessment, IR runbook; sub-processor register.
- On-prem/VPC Helm profile with self-hosted LLM + Tesseract.
**Exit:** can sign BAA/DPA; can deploy single-tenant/on-prem; PHI never leaves the boundary.

## Phase 4 — Scale, integrate & measure (Week 16–24) · *Enterprise-grade*
- Docker + K8s/Helm; CI/CD; Terraform environments (dev/staging/prod).
- Observability (Prometheus/Grafana/Loki/OTel/Sentry); backup/restore + DR drill; load test.
- Evaluation harness + Model Scorecard in CI; expand ICD-10 toward full CM; hybrid retrieval (BM25+vector).
- Billing/quotas/plans; analytics dashboard (real).
- FHIR `Condition`/`DocumentReference` export; X12 837 / superbill; EHR webhooks; HL7 v2 roadmap.
**Exit:** measured accuracy, scalable, integratable; design-partner pilot running on real (BAA) data.

## Phase 5 — GA hardening & launch (Week 22–28) · *Official launch*
- Pen test + remediation; SOC 2 Type II kickoff.
- Pilot feedback incorporated; SLAs, support, status page, on-call.
- Pricing, sales collateral, security questionnaire pack.
- Accessibility (WCAG 2.1 AA); docs & onboarding.
**Exit:** General Availability for clinics/hospitals/billing/insurance teams.

---

## Milestone summary
| Milestone | Phase | What it unlocks |
|---|---|---|
| **M0 Secure** | 0 | Internal testing |
| **M1 Multi-tenant** | 1 | Real accounts & data |
| **M2 Workflow** | 2 | Private beta (design partners) |
| **M3 Compliant** | 3 | BAA / on-prem / first PHI |
| **M4 Scalable+Measured** | 4 | Pilot on real data; integrations |
| **M5 GA** | 5 | Official launch |

## Honest expectation
From today's prototype to credible GA for regulated buyers is **~6–9 months** of focused
work. The clinical core is done well and should be preserved; the remaining 65% is the
platform, workflow, compliance, reliability, and measurement that turn a demo into a product.
