# MedCode AI — Complete Production Feature List

Legend: **[H]** Have (real) · **[P]** Partial/Mock · **[N]** Net-new · Priority **P0** (launch blocker) / **P1** (GA) / **P2** (post-GA).

## A. Identity, Access & Tenancy
| Feature | State | Priority |
|---|---|---|
| Email/password auth | [H] | P0 |
| Vetted JWT (access+refresh, revocation, rotation, `jti`) | [N] | P0 |
| SSO / OIDC / SAML (hospital IdP) | [N] | P1 |
| MFA / TOTP | [N] | P1 |
| Password policy, lockout, breach-password check | [N] | P0 |
| Role-Based Access Control (admin, org_admin, doctor, coder, reviewer, auditor, billing) | [N] | P0 |
| Organizations / workspaces (multi-tenant) | [N] | P0 |
| Org-scoped data isolation (row-level) | [N] | P0 |
| Team/department grouping & assignment | [P] (mock) | P1 |
| User invitation & onboarding flow | [N] | P1 |
| Session management & device list | [N] | P2 |

## B. Document Intake & OCR
| Feature | State | Priority |
|---|---|---|
| PDF / image / DOCX / txt extraction | [H] | P0 |
| Digital-vs-scanned PDF detection | [H] | P0 |
| pdfplumber (digital) + Tesseract (scanned) | [H] | P0 |
| Image preprocessing (grayscale, upscale, contrast, sharpen) | [H] | P1 |
| Deskew / denoise / orientation (OSD) correction | [P] (partial) | P1 |
| Table extraction (labs as structured rows) | [P] | P1 |
| Handwriting fallback + low-confidence flag | [P] | P1 |
| OCR confidence score + low-confidence token highlighting | [P] | P1 |
| Manual correction UI (editable extracted text) | [N] | P1 |
| Extraction preview before coding | [N] | P0 |
| Secure file handling (AV scan, type allow-list, size cap) | [N] | P0 |
| Batch upload (multi-file, folder, zip) | [N] | P1 |
| Document queue (async processing) | [N] | P0 |
| Structured extractors (lab/Rx/discharge schemas) | [P] | P1 |

## C. Clinical NLP
| Feature | State | Priority |
|---|---|---|
| Diagnosis / symptom / medication extraction | [H/P] | P0 |
| Allergy detection | [H] | P1 |
| Lab value & vitals extraction | [H] | P0 |
| Demographics extraction | [H] | P1 |
| Negation detection (deny/no/ruled-out) | [N] | P0 |
| Temporal context (history vs active vs family) | [N] | P1 |
| Abbreviation expansion dictionary | [P] | P1 |
| Indian prescription/lab format support | [H] | P1 |
| Noisy-OCR-tolerant parsing | [P] | P1 |
| Clinical NER model (scispaCy/medCAT) augmentation | [N] | P2 |

## D. ICD-10 Coding Intelligence
| Feature | State | Priority |
|---|---|---|
| BM25 retrieval of verified candidates | [H] | P0 |
| Constrained LLM selection (no free generation) | [H] | P0 |
| DB re-validation of every code | [H] | P0 |
| Principal vs secondary diagnosis | [H] | P0 |
| Symptom vs confirmed diagnosis separation | [H] | P1 |
| Complication / comorbidity tagging | [H] | P1 |
| Per-code confidence | [H] | P0 |
| Evidence snippets w/ char offsets into source | [P] | P0 |
| Code justification + ICD coding notes | [H] | P1 |
| "Coder review required" routing flag | [N] | P0 |
| Missing-documentation warnings | [H] | P1 |
| Physician query suggestions | [H] | P1 |
| Full ICD-10-CM code set (~74k) | [N] | P1 |
| HCC / risk-adjustment hints | [N] | P2 |

## E. Human-in-the-Loop Workflow
| Feature | State | Priority |
|---|---|---|
| Case/document persistence | [N] | P0 |
| Review state machine (draft→coded→in_review→approved/rejected→finalized) | [N] | P0 |
| Reviewer assignment & queue | [N] | P0 |
| Coder corrections capture (add/remove/edit codes) | [N] | P0 |
| Confidence-based auto-routing to review | [N] | P0 |
| Sign-off / e-signature & lock | [N] | P1 |
| Reviewer correction-rate metric | [N] | P1 |
| Comments / threaded notes per case | [N] | P1 |

## F. Reporting, Export & Integration
| Feature | State | Priority |
|---|---|---|
| PDF clinical coding report | [H] | P1 |
| CSV / TSV export | [H] | P1 |
| Email report | [H] | P2 |
| Structured ICD coding report (JSON) | [H] | P0 |
| Billing-system export (837/superbill-friendly) | [N] | P1 |
| FHIR `Condition`/`DocumentReference` export | [N] | P1 |
| HL7 v2 roadmap | [N] | P2 |
| EHR integration APIs (webhooks + REST) | [N] | P1 |

## G. Admin, Analytics & Notifications
| Feature | State | Priority |
|---|---|---|
| Admin dashboard (users, orgs, usage, health) | [N] | P0 |
| Analytics dashboard (volume, accuracy, latency, review rate) | [P] (mock) | P1 |
| Audit log viewer | [N] | P0 |
| Activity history per case/user | [N] | P0 |
| Notification system (in-app + email; assignment, low-confidence, completion) | [N] | P1 |
| Usage quotas & plan limits | [N] | P1 |
| Billing/workspace plan management | [P] | P1 |

## H. Platform, Reliability & Compliance
| Feature | State | Priority |
|---|---|---|
| Postgres + migrations | [N] | P0 |
| Async task queue + workers | [N] | P0 |
| Object storage for documents (encrypted) | [N] | P0 |
| Encryption at rest + in transit (TLS) | [N] | P0 |
| Rate limiting / WAF | [N] | P0 |
| Centralized structured logging | [N] | P0 |
| Metrics + tracing + error tracking | [N] | P1 |
| Backup / restore / DR | [N] | P1 |
| CI/CD pipeline | [N] | P0 |
| Docker + Kubernetes/Helm | [N] | P1 |
| Consent workflow | [N] | P1 |
| Data retention & purge scheduler | [N] | P1 |
| PHI minimization enforcement | [N] | P0 |
| HIPAA/DPDP control set + BAA/DPA readiness | [N] | P1 |
| On-prem / VPC private deployment option | [N] | P1 |
| Evaluation harness (accuracy/recall/hallucination) | [N] | P1 |
| Automated test suite (unit/integration/e2e) | [N] | P0 |
