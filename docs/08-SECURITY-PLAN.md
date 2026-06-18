# MedCode AI — Security Plan

## 0. IMMEDIATE incident (do first)
The uploaded `medcode-v2-persistent.zip` contained a real `backend/.env` with
**live-looking secrets**: `GROQ_API_KEY`, `JWT_SECRET`, `RAZORPAY_KEY_ID/SECRET`,
Gmail `SMTP_PASS`. Even though the new repo `.gitignore`s `.env`, those values
existed in a committed artifact.
**Actions (today):**
1. **Rotate all of them** (Groq, Razorpay, Gmail app password) and generate a fresh `JWT_SECRET`.
2. Purge the secret-bearing zip from history if this repo is/was shared (`git filter-repo`).
3. Move secrets to a secret manager; never commit again (CI secret-scanning gate).

## 1. Threat model (STRIDE, abridged)
| Threat | Today's exposure | Mitigation |
|---|---|---|
| Spoofing | Hand-rolled 30-day non-revocable JWT; default secret fallback | Vetted JWT lib, short access + rotating refresh, revocation, MFA, SSO |
| Tampering | No integrity on docs; no audit | Content hash, signed URLs, append-only audit, e-sign on finalize |
| Repudiation | No audit trail | Immutable `audit_events`, WORM export |
| Information disclosure | `CORS *`, unencrypted SQLite, raw text → LLM | Lock CORS, encrypt at rest, PHI minimizer, RLS tenancy |
| Denial of service | No rate limiting; sync 120s OCR/LLM | WAF + rate limits, async workers, quotas |
| Elevation of privilege | No RBAC | RBAC + RLS, least privilege DB roles |

## 2. Authentication
- Replace `auth.py` JWT with **PyJWT/Authlib**: 15-min access token + rotating refresh (`jti` in `refresh_tokens`, revoke on logout/breach).
- **Fail closed** if `JWT_SECRET` is missing/default (currently it silently uses a dev secret).
- Password: ≥12 chars, breach-check (HIBP k-anonymity), bcrypt/argon2 (keep current PBKDF2 ok), lockout after N failures (`users.failed_logins`/`locked_until`).
- **MFA (TOTP)** for privileged roles; **SSO (OIDC/SAML)** for hospital IdPs.

## 3. Authorization
- **RBAC** (7 roles) + **Postgres RLS** for tenant isolation (defense in depth).
- Least-privilege DB role for the app (`REVOKE UPDATE,DELETE ON audit_events`).
- Object-store access only via short-lived signed URLs scoped to `org/{org_id}/...`.

## 4. Data protection
- **In transit:** TLS 1.2+ everywhere; HSTS; mTLS between services where feasible.
- **At rest:** Postgres TDE/volume encryption; **S3 SSE-KMS** for documents; per-tenant data keys for higher tiers; encrypt `mfa_secret` at app layer.
- **PHI minimization:** structured-context-only to the LLM (see `07-BACKEND-SERVICES.md §3`).
- **Key management:** KMS/Vault, rotation policy, no secrets in images/env files.

## 5. Application hardening
- Lock **CORS** to allow-listed origins (today `*`).
- Security headers (CSP, X-Frame-Options, HSTS, Referrer-Policy) + helmet-equivalent.
- Input validation (pydantic), output encoding, parameterized SQL (already used).
- **File upload safety:** MIME allow-list, 25MB cap, magic-byte check, **AV scan (ClamAV)**, content-hash dedupe, render previews in a sandbox.
- Rate limiting per token + per org; bot/DDoS via WAF/CDN.
- Dependency scanning (pip-audit, npm audit), SAST, secret-scanning in CI; container image scanning.

## 6. Logging, monitoring, response
- Structured logs **without PHI** (log IDs, not contents); PHI access recorded in `audit_events` only.
- Alerting on auth anomalies, error spikes, quota abuse, provider failures.
- **Incident response runbook**: detect → contain → eradicate → notify (HIPAA 60-day breach rule / DPDP notification) → post-mortem.
- Annual **pen test** + continuous vulnerability management before enterprise deals.

## 7. SDLC
- Branch protection, mandatory review, CI gates (tests, SAST, secret scan, dep scan).
- Signed images, SBOM, least-privilege CI credentials (OIDC, no long-lived keys).
- This repo's `/security-review` and `/code-review` skills should run on every PR.

## 8. Security backlog priority
**P0:** rotate keys · real JWT+revocation · lock CORS · rate limiting · encrypt at rest · AV scan uploads · fail-closed secrets.
**P1:** RBAC+RLS · MFA · audit log · WAF · pen test.
**P2:** SSO · per-tenant keys · mTLS.
