# MedCode AI — Product Launch Checklist

Gate legend: ⛔ blocker for the stated launch type.

## A. Security & secrets
- [ ] ⛔ Rotate all leaked secrets (Groq, Razorpay, Gmail, JWT) and purge from history
- [ ] ⛔ Vetted JWT (access+refresh, revocation); fail-closed on missing secret
- [ ] ⛔ CORS locked to allow-list; security headers; HSTS
- [ ] ⛔ Rate limiting + WAF
- [ ] ⛔ Upload AV scan + MIME allow-list + size cap
- [ ] Secrets in vault/secret-manager; CI secret-scanning
- [ ] Dependency/SAST/container scans green
- [ ] External penetration test passed (enterprise)

## B. Data, tenancy & compliance
- [ ] ⛔ Postgres + migrations; org-scoped RLS
- [ ] ⛔ Encryption at rest (DB + object store) and in transit
- [ ] ⛔ PHI minimizer enforced (no raw chart to LLM)
- [ ] ⛔ Immutable audit log + viewer
- [ ] ⛔ BAA-covered or self-hosted LLM (no PHI to non-BAA provider)
- [ ] Consent workflow + retention/erasure scheduler
- [ ] Data-principal rights endpoints (DPDP) / patient rights (HIPAA)
- [ ] Privacy policy, ToS, BAA/DPA templates reviewed by counsel
- [ ] Sub-processor register published

## C. Core product
- [ ] ⛔ RBAC (admin/doctor/coder/reviewer/auditor/billing)
- [ ] ⛔ Case/document persistence (no more stateless analyze-only)
- [ ] ⛔ Async OCR/coding workers + document queue
- [ ] ⛔ HITL review workflow (submit→review→approve/reject→finalize+sign)
- [ ] Batch upload; retry system; notifications
- [ ] Manual extraction-correction UI + evidence-highlight view
- [ ] Admin dashboard, analytics, audit viewer (real, not mock)
- [ ] Export: PDF/CSV/JSON + FHIR `Condition` (billing/EHR)
- [ ] Replace all mock localStorage dashboards with API-backed data

## D. Clinical quality
- [ ] ⛔ Evaluation harness live; Model Scorecard published
- [ ] ⛔ Retrieval Recall@30 ≥ 0.95 on Coding-Gold
- [ ] ⛔ Hallucination rate = 0% verified (DB-validation invariant tested)
- [ ] Expand ICD-10 set toward full ICD-10-CM (380 → target)
- [ ] Negation/temporal handling validated (safety)
- [ ] Drug-interaction source licensed or clearly scoped as "non-exhaustive"
- [ ] Clinical disclaimer + "assistive, coder-verified" labeling on every output

## E. Reliability & ops
- [ ] ⛔ Automated tests (unit/integration/e2e) with meaningful coverage
- [ ] ⛔ CI/CD pipeline
- [ ] Docker images + K8s/Helm (and on-prem profile)
- [ ] Monitoring, metrics, tracing, error tracking, alerting
- [ ] Backup + restore tested; DR runbook + RTO/RPO defined
- [ ] Load test to expected peak; autoscaling verified
- [ ] Status page + incident runbook + on-call

## F. Business / go-to-market
- [ ] Plans, quotas, billing, invoicing
- [ ] Onboarding docs, in-app help, support SLAs
- [ ] Pilot with 1–2 design-partner clinics; signed feedback
- [ ] Pricing validated; sales collateral; security questionnaire pack (SIG-lite)

## Launch tiers
- **Private beta (design partners, synthetic/limited PHI under BAA):** A(P0) + C(persistence, RBAC, async, review) + D(eval harness) + E(tests, CI, monitoring).
- **General availability (paid hospital/clinic):** everything ⛔ above + B fully + E(DR, load) + F.
- **Enterprise / on-prem:** + pen test, SOC 2 in progress, Helm on-prem profile, self-hosted LLM.
