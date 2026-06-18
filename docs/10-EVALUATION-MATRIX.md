# MedCode AI — Evaluation Matrix & Framework

> **Today there is no measurement.** Every quality claim is currently unverified. This
> framework defines what to measure, how, the targets, and the gates. Build it before GA —
> a hospital's first question is "how accurate is it, and how do you know?"

## 1. Golden datasets
| Dataset | Contents | Use |
|---|---|---|
| OCR-Gold | 200+ docs (digital PDF, clean scan, photocopy, handwritten, Indian lab/Rx) with ground-truth text + field labels | OCR/NLP metrics |
| Coding-Gold | 300+ de-identified charts coded by ≥2 certified coders (CCS/CPC), adjudicated | Coding accuracy |
| Retrieval-Gold | queries → relevant ICD-10 codes | Recall@K / Precision@K |
| Adversarial | garbled OCR, non-medical text, contradictory notes | Hallucination + safety |

All datasets **de-identified** (Safe-Harbor) and access-controlled.

## 2. Metrics, targets, gates

### OCR / extraction
| Metric | Definition | Target (printed / handwritten) | Gate |
|---|---|---|---|
| CER | char error rate vs ground truth | ≤ 2% / ≤ 15% | block ship if +1% regression |
| WER | word error rate | ≤ 5% / ≤ 25% | — |
| OCR confidence calibration | predicted vs actual accuracy (ECE) | ECE ≤ 0.1 | confidence must be trustworthy for routing |
| Table-cell F1 | lab grid extraction | ≥ 0.90 | — |
| Field extraction F1 | drug/dose/value/unit | ≥ 0.92 | — |
| Auto-routed-to-review % | docs below threshold | tracked (expect 10–30%) | — |

### NLP
| Metric | Target |
|---|---|
| Entity F1 (diagnosis/med/lab/vital) | ≥ 0.90 |
| Negation detection F1 | ≥ 0.90 (safety-critical) |
| Demographic extraction F1 | ≥ 0.95 |

### Retrieval (BM25 / hybrid)
| Metric | Target |
|---|---|
| Recall@30 | ≥ 0.95 (the correct code must be in candidates the LLM picks from) |
| Recall@10 | ≥ 0.85 |
| Precision@10 | ≥ 0.40 |
| MRR | ≥ 0.6 |

> Recall@K is the **most important retrieval metric** here: if the right code isn't
> retrieved, the constrained LLM *cannot* select it — by design. This is also why the
> 380-code DB must grow toward full ICD-10-CM.

### Coding accuracy (vs adjudicated coders)
| Metric | Target |
|---|---|
| Principal-dx exact match | ≥ 0.85 |
| Principal-dx category (3-char) match | ≥ 0.92 |
| Secondary-dx code-set F1 | ≥ 0.80 |
| Confidence calibration (ECE) | ≤ 0.1 |

### Safety / trust
| Metric | Definition | Target |
|---|---|---|
| **Hallucination rate** | % output codes not in `icd10_codes` | **0%** (hard invariant; validation blocks them) |
| Validation failure rate | % LLM codes rejected by DB check | tracked; high = retrieval/prompt issue |
| Unsupported-evidence rate | codes whose evidence span isn't in source | ≤ 2% |
| Over-coding rate | codes added beyond ground truth | ≤ 10% |
| Negation errors | coded a negated/ruled-out condition | ≤ 1% (safety-critical) |

### Operational
| Metric | Target |
|---|---|
| Processing latency p50 / p95 (text) | ≤ 6s / ≤ 15s |
| Processing latency p95 (scanned multipage) | ≤ 60s (async) |
| Document success rate | ≥ 98% complete without manual retry |
| Reviewer correction rate | tracked over time (should fall) — codes changed by reviewer ÷ codes proposed |
| Auto-approve rate (high-confidence, accepted as-is) | tracked (efficiency KPI) |

## 3. How to run
- **Offline harness** (`eval/`): nightly + per-PR on model/prompt/index changes; outputs a scorecard JSON + Markdown; fails CI on gate regressions.
- **Online/shadow:** log every production result; weekly compare a sampled, coder-adjudicated subset to estimate live accuracy and calibration.
- **Human-in-the-loop signal:** reviewer corrections feed back as labeled data (active learning) to improve retrieval and prompts.

## 4. Reporting
A single **Model Scorecard** per release: dataset versions, all metrics vs targets,
deltas vs previous release, known failure modes. This artifact is what you show buyers
and auditors — and it's what currently doesn't exist.
