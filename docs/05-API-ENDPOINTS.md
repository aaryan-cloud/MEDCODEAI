# MedCode AI — API Specification

REST, JSON, versioned under `/api/v1`. All endpoints (except health/auth) require
`Authorization: Bearer <access_token>` and are **org-scoped + RBAC-guarded**.
Roles: `super_admin, org_admin, doctor, coder, reviewer, auditor, billing`.

> **Currently implemented** (Flask, `backend/app.py`): `/api/health`, `/api/auth/{register,login,me}`,
> `/api/payment/*`, `/api/analyze`, `/api/report/{download,email}`, `/api/search-codes`, `/api/code-info/<code>`.
> Everything below is the target v1 surface; **[H]** = exists today (maps to current route), **[N]** = net-new.

## Auth & identity
| Method | Path | Role | Notes |
|---|---|---|---|
| POST | `/api/v1/auth/register` | public | org signup creates org + org_admin **[H]** |
| POST | `/api/v1/auth/login` | public | returns access+refresh **[H, harden]** |
| POST | `/api/v1/auth/refresh` | public | rotate refresh token **[N]** |
| POST | `/api/v1/auth/logout` | auth | revoke refresh `jti` **[N]** |
| GET | `/api/v1/auth/me` | auth | profile + roles + org **[H]** |
| POST | `/api/v1/auth/mfa/enroll` `/verify` | auth | TOTP **[N]** |
| POST | `/api/v1/auth/sso/oidc/callback` | public | hospital IdP **[N]** |

## Organizations & users (admin)
| Method | Path | Role |
|---|---|---|
| GET/PATCH | `/api/v1/org` | org_admin |
| GET | `/api/v1/org/usage` | org_admin, billing |
| GET/POST | `/api/v1/org/users` | org_admin (list/invite) |
| PATCH/DELETE | `/api/v1/org/users/{id}` | org_admin (roles, deactivate) |
| GET/PUT | `/api/v1/org/retention` | org_admin |
| GET | `/api/v1/admin/orgs` | super_admin |

## Cases
| Method | Path | Role |
|---|---|---|
| GET | `/api/v1/cases?status=&assigned=&q=&page=` | coder, reviewer, doctor |
| POST | `/api/v1/cases` | coder, doctor |
| GET | `/api/v1/cases/{id}` | scoped |
| PATCH | `/api/v1/cases/{id}` | coder (assign, priority, status) |
| GET | `/api/v1/cases/{id}/timeline` | scoped (audit/activity) |
| DELETE | `/api/v1/cases/{id}` | org_admin (soft delete) |

## Documents & extraction
| Method | Path | Role | Notes |
|---|---|---|---|
| POST | `/api/v1/cases/{id}/documents` | coder | presigned upload init; AV scan **[N]** |
| POST | `/api/v1/documents/batch` | coder | multi-file / zip batch **[N]** |
| GET | `/api/v1/documents/{id}` | scoped | status + metadata |
| GET | `/api/v1/documents/{id}/extraction` | scoped | text + confidence_map + structured **[N]** |
| PATCH | `/api/v1/documents/{id}/extraction` | coder | manual correction write-back **[N]** |
| POST | `/api/v1/documents/{id}/retry` | coder | re-run failed stage **[N]** |
| GET | `/api/v1/documents/{id}/preview` | scoped | page images (signed URL) **[N]** |

## Coding
| Method | Path | Role | Notes |
|---|---|---|---|
| POST | `/api/v1/documents/{id}/code` | coder | enqueue coding job **[H→async]** |
| POST | `/api/v1/analyze` | coder | **stateless** quick analyze (current behavior) **[H]** |
| GET | `/api/v1/coding-results/{id}` | scoped | full result + coded_items |
| GET | `/api/v1/codes/search?q=&limit=` | any | BM25 lookup **[H]** |
| GET | `/api/v1/codes/{code}` | any | validate/describe code **[H]** |

## Review workflow (HITL)
| Method | Path | Role |
|---|---|---|
| GET | `/api/v1/review/queue` | reviewer |
| POST | `/api/v1/coding-results/{id}/submit` | coder (→ in_review) |
| POST | `/api/v1/coding-results/{id}/review` | reviewer (approve/reject/changes + corrections) |
| POST | `/api/v1/coding-results/{id}/finalize` | reviewer (lock + e-sign) |
| POST | `/api/v1/coded-items/{id}` | coder/reviewer (edit/add/remove a code) |

## Export & integration
| Method | Path | Role |
|---|---|---|
| GET | `/api/v1/coding-results/{id}/export?format=pdf\|csv\|tsv\|json\|fhir\|x12` | coder, billing |
| POST | `/api/v1/report/email` | coder **[H]** |
| GET | `/api/v1/fhir/Condition?case={id}` | integration **[N]** |
| POST | `/api/v1/webhooks` (manage) | org_admin **[N]** |

## Notifications & analytics
| Method | Path | Role |
|---|---|---|
| GET | `/api/v1/notifications` / `POST .../read` | auth |
| GET | `/api/v1/analytics/overview` | org_admin (volume, latency, review-rate, accuracy) |
| GET | `/api/v1/audit?entity=&actor=&from=&to=` | auditor, org_admin |

## Health & ops
| Method | Path |
|---|---|
| GET | `/api/health` **[H]** · `/api/v1/health/live` · `/api/v1/health/ready` |
| GET | `/metrics` (Prometheus, internal) |

## Cross-cutting conventions
- **Errors:** RFC-7807 `application/problem+json` `{type,title,status,detail,trace_id}`.
- **Idempotency:** `Idempotency-Key` header on POST upload/code/export.
- **Pagination:** cursor-based `?cursor=&limit=` (max 100).
- **Rate limits:** per-token + per-org; `429` with `Retry-After`.
- **Versioning:** path `/api/v1`; breaking changes ⇒ `/api/v2`.
- **Async pattern:** mutation returns `202` + `job_id`; poll `GET .../{id}` for status; optional webhook on completion.
