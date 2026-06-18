# MedCode AI — Production Readiness Assessment (Brutally Honest)

**Date:** 2026-06-18
**Reviewer role:** Healthcare AI product architect / clinical informatics / compliance
**Verdict:** **Strong prototype. NOT launch-ready for hospitals, clinics, billing, or insurance workflows.** It is roughly a **35/100** on production readiness for a regulated clinical SaaS. The clinical reasoning core (BM25 → constrained LLM → DB validation) is genuinely good and is the hardest part to get right. Almost everything *around* it that a hospital buyer requires is missing or simulated.

This document is deliberately blunt. The rest of the `docs/` folder is the constructive plan.

---

## 1. What actually exists today (verified by reading the code)

| Area | Status | Evidence |
|------|--------|----------|
| OCR extraction (PDF/image/DOCX/txt) | ✅ Real, decent | `backend/services/ocr_service.py` — pdfplumber + Tesseract, digital-vs-scanned detection, multi-PSM, confidence estimate |
| Medical NLP (regex/heuristic) | ✅ Real, no ML | `backend/services/medical_nlp.py` — meds/vitals/labs/allergy patterns, Indian lab formats |
| BM25 ICD retrieval | ✅ Real | `backend/services/icd_service.py` — `rank_bm25` over ~380 codes |
| Constrained LLM coding | ✅ Real, good design | `backend/services/llm_service.py` — LLM must pick from retrieved candidates; every code re-validated against DB |
| Drug interaction checker | ✅ Real (hardcoded rules) | `llm_service.check_drug_interactions` — ~13 rule pairs |
| Abnormal lab/vital flagging | ✅ Real | `medical_nlp.py` + `app.py _build_search_queries` |
| PDF report / email / WhatsApp | ✅ Real | `report_service.py`, `email_service.py`, `App.jsx ShareBar` |
| Auth (register/login/JWT) | ⚠️ Works, insecure for prod | `backend/auth.py` — hand-rolled JWT, 30-day non-revocable token |
| Payments (Razorpay ₹1) | ✅ Real (test mode) | `backend/payment.py` |
| Frontend dashboard | ⚠️ Mostly **mock UI** | `App.jsx` — Home/Inbox/Doctor/Departments/Schedule are `localStorage` fake data |

**Bottom line:** the *pipeline* is real. The *product* (multi-user, roles, workflow, audit, tenancy, compliance) is largely a façade.

---

## 2. Brutal gap list — what is MISSING and blocks launch

### 2.1 Security (BLOCKER)
- **A real `.env` with live-looking secrets was shipped inside the committed zip** (Groq key, JWT secret, Razorpay keys, Gmail app password). This is a credential-leak incident. **Action: rotate every one of those keys immediately.** They have been excluded from the new repo and `.gitignore`'d, but they already existed in git history of the zip.
- **Hand-rolled JWT** (`auth.py`) instead of a vetted library. Tokens are valid 30 days, **cannot be revoked**, no refresh, no rotation, no `jti`, no logout. `JWT_SECRET` defaults to `"dev_secret_change_in_production"` if env is missing — silent insecure fallback.
- **CORS is `origins: "*"`** on all `/api/*` — any website can call the API with a user's token.
- **No rate limiting, no brute-force lockout, no account lockout, no password complexity** beyond 6 chars.
- **No RBAC at all.** There are no roles. The task asks for doctor/coder/reviewer/admin — none exist in code or schema.
- **No encryption at rest.** SQLite file, plaintext uploaded documents in memory/disk. PHI unprotected.
- **No audit log.** Regulated healthcare requires immutable access/audit trails. None exists.
- **SQLite** as the only datastore — single-writer, no concurrency, no backup/restore, not multi-tenant.

### 2.2 Compliance (BLOCKER for hospital sale)
- **No HIPAA program**: no BAA, no access controls, no audit controls, no PHI inventory, no breach process, no data-retention policy, no minimum-necessary enforcement.
- **No India DPDP Act 2023 readiness**: no consent capture, no data-principal rights workflow, no data-localization story.
- **PHI minimization claim is only partially true.** `llm_service.analyze` sends the **first 3000 chars of the raw document** to the LLM (`text[:3000]`), not just structured fields. The architecture *aspires* to minimization but the code violates it. This must be fixed before any "PHI-safe" claim.
- **No consent workflow, no data subject access/erasure, no retention scheduler.**

### 2.3 Multi-tenancy & enterprise (BLOCKER for SaaS)
- **No organizations/workspaces.** Every user is global. No tenant isolation, no per-org data scoping.
- **No usage limits / quotas / plans** beyond a single ₹1 personal subscription.
- **No admin dashboard, no user management, no org management.**

### 2.4 Clinical workflow (BLOCKER for coder/billing teams)
- **No human-in-the-loop approval workflow.** Coding results are generated and shown; there is no "submit → review → approve/reject → finalize" state machine, no reviewer assignment, no correction capture.
- **No case/patient/document management.** Each `/api/analyze` call is stateless and fire-and-forget. Nothing is persisted. You cannot list past documents, reopen a case, or track status. The "cases" in the UI are `localStorage` fiction.
- **No document queue, no batch upload, no retry system, no async processing.** Everything is synchronous in one HTTP request with a 120s timeout. A scanned 30-page PDF will block a worker and likely time out.
- **No coder review status, no confidence-driven routing** ("low confidence → must review").

### 2.5 Reliability / Ops (BLOCKER)
- **No tests.** Zero. For a clinical product this is disqualifying.
- **No CI/CD, no Docker, no Kubernetes, no IaC.**
- **No monitoring, metrics, structured logging, error tracking, or tracing.**
- **No background workers / queue** (Celery/RQ/Arq). LLM + OCR are slow and external; they must be async.
- **No backup/restore or disaster recovery.**
- **No migrations** (schema is created inline with `CREATE TABLE IF NOT EXISTS`).

### 2.6 Data / model quality
- **~380 ICD-10 codes** in `icd10_data.py`. Real ICD-10-CM is **~74,000 codes**. Retrieval recall is structurally capped — most real diagnoses cannot be coded. This is the single biggest *clinical* limitation.
- **No evaluation harness.** No measured OCR accuracy, coding accuracy, recall@k, or hallucination rate. All quality claims are currently unverified.
- **Drug interactions are ~13 hardcoded pairs.** Fine as a demo, dangerous if presented as comprehensive. Needs a real source (e.g., licensed DB) or explicit "not exhaustive" disclaiming.

---

## 3. Honest risk callouts a hospital buyer WILL raise

1. **"Show me your audit log and access controls."** → none today.
2. **"Where is patient data stored and how is it encrypted?"** → unencrypted SQLite.
3. **"Can you sign a BAA / DPA?"** → not until §2.1–2.2 are done.
4. **"What's your coding accuracy on our charts, measured how?"** → no evaluation exists.
5. **"Your code DB has 380 codes — we need full ICD-10-CM."** → true, must expand.
6. **"You send raw notes to a third-party LLM (Groq)?"** → yes today; this needs a BAA-covered model, PHI minimization, or on-prem inference.

---

## 4. What to keep (do NOT rebuild)
- The **retrieval-constrained, DB-validated coding pattern** in `llm_service.py`. This is the right anti-hallucination design.
- The **OCR digital-vs-scanned routing** and multi-PSM Tesseract approach.
- The **regex NLP** as a fast, offline first pass (augment, don't replace).
- The **confidence + evidence + physician-query** output shape — it's exactly what coders want.

## 5. Recommended sequencing (summary — see `12-ROADMAP.md`)
1. **Phase 0 — Stop the bleeding:** rotate leaked keys, real JWT lib + refresh + revocation, lock CORS, add rate limiting, move secrets to a vault.
2. **Phase 1 — Persistence & tenancy:** Postgres, migrations, orgs/users/roles (RBAC), cases/documents/results persisted, audit log.
3. **Phase 2 — Workflow:** async queue, document queue + batch upload, HITL review state machine, notifications.
4. **Phase 3 — Compliance:** encryption at rest, PHI minimization fix, consent + retention, access logging, HIPAA/DPDP controls.
5. **Phase 4 — Scale & integrate:** Docker/K8s, CI/CD, observability, FHIR/HL7 roadmap, billing-system export, full ICD-10-CM.
6. **Phase 5 — Evaluation & GA:** evaluation matrix instrumented, pilot with a partner clinic, security review, launch.

**Estimated effort to credible GA:** 4–6 engineers, ~6–9 months. This is a real product, not a weekend of polish — and that's the honest answer.
