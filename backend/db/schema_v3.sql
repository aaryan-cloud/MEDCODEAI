-- ===========================================================================
-- MedCode AI — Production Database Schema (v3, PostgreSQL 16)
-- Multi-tenant, RBAC, case/document management, HITL review, audit, compliance.
--
-- Conventions:
--   * UUID primary keys (gen_random_uuid via pgcrypto).
--   * Every PHI-bearing table carries org_id and is protected by Row-Level Security.
--   * Timestamps are timestamptz, UTC.
--   * Soft-delete via deleted_at where retention/erasure matters.
-- Apply RLS GUC per request:  SET app.current_org = '<org uuid>';
-- ===========================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS citext;
-- CREATE EXTENSION IF NOT EXISTS vector;  -- enable for hybrid retrieval (pgvector)

-- ── Enums ──────────────────────────────────────────────────────────────────
CREATE TYPE user_role        AS ENUM ('super_admin','org_admin','doctor','coder','reviewer','auditor','billing');
CREATE TYPE plan_tier        AS ENUM ('trial','clinic','hospital','enterprise');
CREATE TYPE doc_status       AS ENUM ('uploaded','scanning','extracted','ready_for_coding','coding','coded','in_review','approved','rejected','finalized','exported','failed');
CREATE TYPE doc_kind         AS ENUM ('prescription','lab_report','discharge_summary','clinical_note','scanned','other');
CREATE TYPE review_decision  AS ENUM ('approved','rejected','changes_requested');
CREATE TYPE code_relationship AS ENUM ('principal','secondary','complication','comorbidity','symptom','history','excluded');
CREATE TYPE confidence_level AS ENUM ('high','medium','low');
CREATE TYPE consent_status   AS ENUM ('granted','withdrawn','expired');
CREATE TYPE notif_type       AS ENUM ('assignment','low_confidence','completion','review_requested','approved','rejected','system');

-- ── Organizations / tenancy ────────────────────────────────────────────────
CREATE TABLE organizations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    slug            TEXT UNIQUE NOT NULL,
    plan            plan_tier NOT NULL DEFAULT 'trial',
    country         TEXT DEFAULT 'IN',
    data_region     TEXT DEFAULT 'ap-south-1',          -- data localization
    settings        JSONB NOT NULL DEFAULT '{}',
    monthly_doc_quota   INTEGER NOT NULL DEFAULT 100,
    monthly_doc_used    INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id),
    email           CITEXT NOT NULL,
    name            TEXT NOT NULL,
    password_hash   TEXT,                                 -- null when SSO-only
    is_sso          BOOLEAN NOT NULL DEFAULT false,
    mfa_secret      TEXT,                                 -- encrypted at app layer
    is_active       BOOLEAN NOT NULL DEFAULT true,
    failed_logins   INTEGER NOT NULL DEFAULT 0,
    locked_until    TIMESTAMPTZ,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ,
    UNIQUE (org_id, email)
);

-- A user may hold multiple roles within their org.
CREATE TABLE user_roles (
    user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role      user_role NOT NULL,
    PRIMARY KEY (user_id, role)
);

-- ── Auth: refresh tokens / revocation ──────────────────────────────────────
CREATE TABLE refresh_tokens (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    jti          UUID NOT NULL UNIQUE,                    -- token id; access tokens carry matching jti family
    token_hash   TEXT NOT NULL,                           -- sha256 of refresh token
    user_agent   TEXT,
    ip           INET,
    expires_at   TIMESTAMPTZ NOT NULL,
    revoked_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Patient / case management ──────────────────────────────────────────────
-- Patient identifiers are PHI: store minimally; MRN tokenized where possible.
CREATE TABLE patients (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL REFERENCES organizations(id),
    mrn           TEXT,                                    -- medical record number (org scope)
    display_name  TEXT,                                    -- may be redacted/tokenized
    dob           DATE,
    sex           TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ,
    UNIQUE (org_id, mrn)
);

CREATE TABLE cases (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL REFERENCES organizations(id),
    patient_id    UUID REFERENCES patients(id),
    title         TEXT,
    encounter_date DATE,
    status        doc_status NOT NULL DEFAULT 'uploaded',
    created_by    UUID NOT NULL REFERENCES users(id),
    assigned_coder    UUID REFERENCES users(id),
    assigned_reviewer UUID REFERENCES users(id),
    priority      SMALLINT NOT NULL DEFAULT 3,            -- 1 high .. 5 low
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ
);
CREATE INDEX idx_cases_org_status ON cases(org_id, status);
CREATE INDEX idx_cases_coder ON cases(assigned_coder);

-- ── Documents & extraction ─────────────────────────────────────────────────
CREATE TABLE documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id),
    case_id         UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    kind            doc_kind NOT NULL DEFAULT 'other',
    filename        TEXT NOT NULL,
    mime_type       TEXT,
    size_bytes      BIGINT,
    content_sha256  TEXT,                                  -- dedupe + integrity
    storage_key     TEXT NOT NULL,                         -- encrypted object-store key
    status          doc_status NOT NULL DEFAULT 'uploaded',
    page_count      INTEGER,
    av_scanned      BOOLEAN NOT NULL DEFAULT false,
    av_clean        BOOLEAN,
    error           TEXT,
    uploaded_by     UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);
CREATE INDEX idx_documents_case ON documents(case_id);

-- One row per extraction attempt; latest is authoritative.
CREATE TABLE extractions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id),
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    engine          TEXT NOT NULL,                         -- 'pdfplumber','tesseract','docai'...
    file_type       TEXT,
    raw_text        TEXT,                                  -- PHI
    structured      JSONB NOT NULL DEFAULT '{}',           -- labs/Rx/sections + provenance
    confidence      NUMERIC(4,3),                          -- document-level 0..1
    confidence_map  JSONB,                                 -- per-page/token confidences
    low_conf_spans  JSONB,                                 -- highlight ranges
    corrected_by    UUID REFERENCES users(id),             -- human correction
    corrected_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_extractions_doc ON extractions(document_id);

-- ── Coding results ─────────────────────────────────────────────────────────
CREATE TABLE coding_results (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id),
    case_id         UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    document_id     UUID REFERENCES documents(id),
    extraction_id   UUID REFERENCES extractions(id),
    model           TEXT,                                  -- llm provider/model
    candidate_count INTEGER,                               -- BM25 candidates considered
    coding_summary  TEXT,
    documentation_gaps JSONB DEFAULT '[]',
    physician_query TEXT,
    all_verified    BOOLEAN NOT NULL DEFAULT false,
    coder_review_required BOOLEAN NOT NULL DEFAULT true,
    latency_ms      INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_coding_case ON coding_results(case_id);

-- Individual ICD-10 codes attached to a coding result.
CREATE TABLE coded_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id),
    coding_result_id UUID NOT NULL REFERENCES coding_results(id) ON DELETE CASCADE,
    code            TEXT NOT NULL,                         -- must validate against icd10_codes
    description     TEXT,
    relationship    code_relationship NOT NULL DEFAULT 'secondary',
    confidence      confidence_level NOT NULL DEFAULT 'medium',
    confidence_score NUMERIC(4,3),
    justification   TEXT,
    evidence_span   JSONB,                                 -- {page,char_start,char_end,quote}
    coding_notes    TEXT,
    verified        BOOLEAN NOT NULL DEFAULT false,        -- exists in icd10_codes
    -- review fields
    accepted        BOOLEAN,                               -- coder/reviewer kept it
    edited          BOOLEAN NOT NULL DEFAULT false,
    added_by_human  BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_coded_items_result ON coded_items(coding_result_id);

-- ── Verified ICD-10 reference set (the anti-hallucination source of truth) ──
CREATE TABLE icd10_codes (
    code         TEXT PRIMARY KEY,
    description  TEXT NOT NULL,
    chapter      TEXT,
    category     TEXT,
    keywords     TEXT[],
    is_billable  BOOLEAN NOT NULL DEFAULT true,
    -- embedding VECTOR(384),                              -- for hybrid retrieval
    search_tsv   TSVECTOR
);
CREATE INDEX idx_icd_tsv ON icd10_codes USING GIN(search_tsv);
CREATE INDEX idx_icd_trgm ON icd10_codes USING GIN(description gin_trgm_ops);

-- ── Human-in-the-loop review ───────────────────────────────────────────────
CREATE TABLE reviews (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id),
    case_id         UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    coding_result_id UUID REFERENCES coding_results(id),
    reviewer_id     UUID NOT NULL REFERENCES users(id),
    decision        review_decision,
    comment         TEXT,
    corrections     JSONB,                                 -- diff of codes added/removed/edited
    signed_off      BOOLEAN NOT NULL DEFAULT false,
    signature_hash  TEXT,                                  -- e-sign integrity
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reviews_case ON reviews(case_id);

-- ── Notifications ──────────────────────────────────────────────────────────
CREATE TABLE notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL REFERENCES organizations(id),
    user_id     UUID NOT NULL REFERENCES users(id),
    type        notif_type NOT NULL,
    title       TEXT NOT NULL,
    body        TEXT,
    case_id     UUID REFERENCES cases(id),
    read_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_notif_user_unread ON notifications(user_id) WHERE read_at IS NULL;

-- ── Audit trail (append-only; export to WORM storage) ──────────────────────
CREATE TABLE audit_events (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    org_id      UUID,
    actor_id    UUID,                                      -- null = system
    actor_role  TEXT,
    action      TEXT NOT NULL,                             -- e.g. 'document.view','coding.approve'
    entity_type TEXT,
    entity_id   UUID,
    ip          INET,
    user_agent  TEXT,
    metadata    JSONB NOT NULL DEFAULT '{}',
    phi_accessed BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Audit table must be INSERT-only at the DB grant level:
-- REVOKE UPDATE, DELETE ON audit_events FROM app_role;
CREATE INDEX idx_audit_org_time ON audit_events(org_id, created_at);
CREATE INDEX idx_audit_entity ON audit_events(entity_type, entity_id);

-- ── Consent & retention (compliance) ───────────────────────────────────────
CREATE TABLE consents (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL REFERENCES organizations(id),
    patient_id  UUID REFERENCES patients(id),
    purpose     TEXT NOT NULL,                             -- 'coding','analytics'...
    status      consent_status NOT NULL DEFAULT 'granted',
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    withdrawn_at TIMESTAMPTZ,
    evidence    JSONB                                      -- who/how captured
);

CREATE TABLE retention_policies (
    org_id          UUID PRIMARY KEY REFERENCES organizations(id),
    document_days   INTEGER NOT NULL DEFAULT 2555,         -- ~7 years default
    raw_text_days   INTEGER NOT NULL DEFAULT 2555,
    audit_days      INTEGER NOT NULL DEFAULT 3650,
    auto_purge      BOOLEAN NOT NULL DEFAULT true
);

-- ── Usage metering / billing ───────────────────────────────────────────────
CREATE TABLE usage_events (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    org_id      UUID NOT NULL REFERENCES organizations(id),
    user_id     UUID REFERENCES users(id),
    kind        TEXT NOT NULL,                             -- 'document_processed','export'...
    quantity    INTEGER NOT NULL DEFAULT 1,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_usage_org_time ON usage_events(org_id, created_at);

-- ── Row-Level Security (tenant isolation) ──────────────────────────────────
-- Apply to every PHI table; example for documents:
ALTER TABLE documents     ENABLE ROW LEVEL SECURITY;
ALTER TABLE cases         ENABLE ROW LEVEL SECURITY;
ALTER TABLE extractions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE coding_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE coded_items   ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients      ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews       ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON documents
    USING (org_id = current_setting('app.current_org', true)::uuid);
-- Repeat the analogous policy for each table above.
