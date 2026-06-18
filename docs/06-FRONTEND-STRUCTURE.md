# MedCode AI — Frontend Page & Component Structure

## 1. Honest status of today's frontend
`frontend/src/App.jsx` (545 lines) is a single file. The **coding flow is real** (`PatientView` → `/api/analyze` → results, `ShareBar` export). The **dashboard surfaces are mock** — `Home`, `Inbox`, `Doctor`, `Departments`, `Schedule` use `useLocalState` (localStorage) with invented data. For launch these must become real, role-aware, API-backed pages.

## 2. Target app structure

```
src/
  main.jsx
  app/
    routes.tsx                 # role-guarded routing
    queryClient.ts             # React Query (server state)
    api/                       # typed API client per resource
  context/
    AuthContext.tsx            # [H] keep; add roles, refresh, org
    OrgContext.tsx             # current org + plan + quota
  components/                  # design-system primitives
    DataTable, StatusBadge, ConfidenceBar, EvidenceHighlight,
    FileDropzone, Toast, ConfirmDialog, RoleGate
  features/
    auth/        LoginPage [H], RegisterPage, MfaPage, SsoCallback
    dashboard/   OverviewPage (real analytics)
    upload/      UploadCenter (single + batch + queue)
    cases/       CaseListPage, CaseDetailPage
    documents/   DocumentPreview, ExtractionEditor (manual correction)
    coding/      CodingResultPanel, CodeCard [H], EvidencePanel
    review/      ReviewQueue, ReviewPanel (approve/reject/sign)
    entities/    ExtractedEntitiesPanel (vitals/labs/meds) [H VitalsPanel]
    notifications/ NotificationBell, NotificationList
    admin/       UsersPage, OrgSettings, AuditLogViewer, AnalyticsPage
    billing/     SubscriptionPage [H], UsagePage
```

## 3. Pages & who sees them (RBAC)

| Page | Route | Roles | Source today |
|---|---|---|---|
| Login / Register / MFA | `/login` … | public | `LoginPage` [H] |
| Dashboard Overview | `/` | all | `HomeView` (mock → real) |
| Upload Center | `/upload` | coder, doctor | `PatientView` upload [H] |
| Case List (queue) | `/cases` | coder, reviewer, doctor | mock `DoctorView` → real |
| Case Detail | `/cases/:id` | scoped | new |
| Document Preview + Extraction Editor | `/documents/:id` | coder | new (correction UI) |
| Coding Result | within case detail | coder, reviewer | `CodeCard`/result panels [H] |
| Review Queue | `/review` | reviewer | new |
| Review Panel (approve/sign) | `/review/:id` | reviewer | new |
| Audit History | `/audit` | auditor, org_admin | new |
| Admin · Users | `/admin/users` | org_admin | new |
| Admin · Org Settings | `/admin/settings` | org_admin | new |
| Analytics | `/analytics` | org_admin | mock → real |
| Billing / Usage | `/billing` | org_admin, billing | `SubscriptionPage` [H] |
| Notifications | bell + `/notifications` | all | new |

## 4. Key UX flows
1. **Code a document:** Upload → live status (scanning→extracted→coded) → **Extraction Preview** (highlight low-confidence tokens, allow edit) → **Coding Result** (principal/secondary cards with confidence bar + evidence snippet + justification) → Submit for review.
2. **Review:** Reviewer queue (sorted by `coder_review_required`, confidence, priority) → side-by-side document vs codes → accept/edit/add/remove → approve & e-sign (locks case) or request changes.
3. **Evidence view:** clicking a code scrolls the document preview to the highlighted `evidence_span` — this is the trust feature coders care about most.

## 5. Engineering upgrades
- Migrate `App.jsx` monolith → feature folders; adopt **TypeScript** + **React Query** for server state (replaces `useLocalState` mocks).
- `RoleGate` component + route guards driven by `AuthContext.roles`.
- Replace `axios` baseURL `'/api'` with versioned client + interceptors for token refresh and `problem+json` error toasts.
- Accessibility (WCAG 2.1 AA), since hospital procurement checks it.
- Keep the existing dark clinical aesthetic — it already looks "official"; just wire it to real data.
