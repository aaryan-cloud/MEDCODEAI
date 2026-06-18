# MedCode AI — Compliance Plan (HIPAA-ready + India DPDP)

> **Disclaimer:** engineering guidance, not legal advice. Engage qualified healthcare
> privacy counsel and a security auditor before making compliance claims or signing BAAs/DPAs.

## 1. Regulatory scope
| Framework | Why it applies | Our posture |
|---|---|---|
| **HIPAA** (US) | PHI processing for US covered entities/business associates | Become a compliant **Business Associate**; sign BAAs; implement Security + Privacy + Breach rules |
| **India DPDP Act 2023** | Indian patient personal data | Lawful processing, consent, data-principal rights, breach notification |
| **ABDM / NDHM** (India) | Interop with India's health stack | Roadmap: ABHA linkage, FHIR R4 |
| SOC 2 Type II | Enterprise procurement | Target post-GA |
| GDPR | If EU patients | Mirror DPDP controls + DPO/representative |

## 2. HIPAA control mapping (Security Rule)
| Safeguard | Requirement | Implementation |
|---|---|---|
| Administrative | Risk analysis, workforce training, access management, IR plan | Annual risk assessment, RBAC role reviews, training log, IR runbook (`08-SECURITY-PLAN §6`) |
| Physical | Facility/device controls | Cloud provider under BAA (AWS/GCP/Azure HIPAA); no PHI on laptops |
| Technical | Access control, audit controls, integrity, transmission security | RBAC+RLS, `audit_events`, content hashing + e-sign, TLS/encryption |
| Organizational | BAAs with subcontractors | BAA with cloud + **LLM provider** (or self-host the model) |
| Policies | Documented P&P, 6-yr retention | Policy set + `retention_policies` table |

**Minimum-necessary / PHI minimization:** enforced technically — the LLM gets
structured context only (`phi_minimizer`), not raw charts. Today's code violates
this (`text[:3000]`); fixing it is a compliance prerequisite, not a nicety.

## 3. India DPDP Act 2023 readiness
- **Consent:** capture purpose-bound consent (`consents` table); allow withdrawal; show notice.
- **Data principal rights:** access, correction, erasure, grievance redressal endpoints/workflow.
- **Data fiduciary duties:** purpose limitation, retention limits (`retention_policies`), security safeguards, breach notification to Data Protection Board + affected principals.
- **Data localization:** `organizations.data_region` defaults to India (`ap-south-1`); keep Indian PHI in-region; document cross-border transfer basis if any.
- **Children's data / consent managers:** policy hooks for ABDM consent-manager model.

## 4. Data lifecycle & PHI governance
```
Collect (consent) → Minimize (structured extraction) → Process (coding) →
Store (encrypted, org-scoped) → Access (RBAC + audit) →
Retain (per policy, default ~7y) → Purge (auto, verifiable) / Erase (on request)
```
- **PHI inventory:** documents, extractions.raw_text, patients, coding evidence snippets.
- **De-identification mode:** optional Safe-Harbor-style stripping of 18 identifiers for analytics/eval datasets.
- **Retention scheduler:** `purge` worker enforces `retention_policies`; erasure requests produce an auditable deletion certificate.

## 5. Third-party / sub-processors
- Maintain a **sub-processor register** (cloud, LLM provider, email, AV, payments).
- **LLM provider is the sharpest risk:** Groq (current default) is not a BAA-covered PHI processor. Before any real PHI: (a) switch to a BAA-covered model endpoint, (b) self-host an open model in-VPC, or (c) guarantee only de-identified structured context is sent. Document the choice.

## 6. Deployment options for compliance-sensitive buyers
- **Shared SaaS** (multi-tenant, RLS) — default.
- **Single-tenant VPC** — dedicated DB/storage/keys.
- **On-prem / air-gapped** — Helm chart + self-hosted LLM + Tesseract (no external calls). This is often required to win hospital deals; the architecture supports it because OCR/NLP/BM25 run locally and the LLM is pluggable.

## 7. Compliance backlog
**P0 (before any real PHI):** PHI minimizer enforced · encryption at rest/in transit · audit log · access controls · BAA-covered or self-hosted LLM · breach IR plan.
**P1:** consent workflow · retention/erasure scheduler · data-principal rights endpoints · policies & training · risk assessment.
**P2:** SOC 2 Type II · ISO 27001 · ABDM/FHIR certification · external audit.
