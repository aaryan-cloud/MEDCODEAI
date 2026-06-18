# MedCode AI — Production Blueprint (Docs Index)

This folder is the launch-readiness blueprint that turns the MedCode AI prototype into a
real, regulated healthcare SaaS. Read in order; **start with the honest assessment.**

| # | Document | What it answers |
|---|---|---|
| 00 | [Production Readiness Assessment](00-PRODUCTION-READINESS-ASSESSMENT.md) | Brutally honest gap analysis — what's real, what's missing, what blocks launch |
| 01 | [Production Feature List](01-PRODUCTION-FEATURE-LIST.md) | Every feature, current state, and priority (P0/P1/P2) |
| 02 | [OCR Architecture](02-OCR-ARCHITECTURE.md) | Production-grade extraction pipeline |
| 03 | [System Architecture](03-SYSTEM-ARCHITECTURE.md) | Full target architecture & tech choices |
| 04 | [Database Schema](04-DATABASE-SCHEMA.md) | Data model (DDL: `../backend/db/schema_v3.sql`) |
| 05 | [API Endpoints](05-API-ENDPOINTS.md) | Complete REST surface |
| 06 | [Frontend Structure](06-FRONTEND-STRUCTURE.md) | Pages, components, RBAC-aware UX |
| 07 | [Backend Services](07-BACKEND-SERVICES.md) | Service map; reuse vs replace |
| 08 | [Security Plan](08-SECURITY-PLAN.md) | Threat model + controls (+ secret-leak incident) |
| 09 | [Compliance Plan](09-COMPLIANCE-PLAN.md) | HIPAA + India DPDP readiness |
| 10 | [Evaluation Matrix](10-EVALUATION-MATRIX.md) | Metrics, targets, gates |
| 11 | [Launch Checklist](11-LAUNCH-CHECKLIST.md) | Go/no-go by launch tier |
| 12 | [Roadmap](12-ROADMAP.md) | Phase 0 → GA |

## TL;DR
- **The clinical core is genuinely good** (OCR → NLP → BM25 → constrained LLM → DB validation). Keep it.
- **The product around it is mostly missing or mocked** (no roles, no persistence, no workflow, no audit, no tenancy, no compliance, no tests, no measurement).
- **Do first:** rotate the leaked secrets in the original zip's `.env` (see doc 08), then follow the roadmap.
- **Honest timeline to GA:** ~6–9 months with a small team.
