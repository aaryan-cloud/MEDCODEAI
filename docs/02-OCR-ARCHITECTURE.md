# MedCode AI — Production OCR & Extraction Architecture

## 1. Goals
Turn the current single-pass `ocr_service.py` into a **multi-stage, async, confidence-aware extraction pipeline** that produces *structured, reviewable* output with provenance (page, bbox, confidence) for every field — so a human can correct it before coding.

## 2. Current vs Target

| Aspect | Current (`ocr_service.py`) | Target |
|---|---|---|
| Execution | Synchronous in `/api/analyze` | Async worker job, status-polled |
| Formats | PDF, image, DOCX, txt | + TIFF multipage, HEIC, password PDFs, email (.eml) |
| Routing | text<80 chars ⇒ OCR | Per-page digital/scanned classification |
| Preprocess | grayscale, upscale, contrast, sharpen | + deskew (Hough/OSD), denoise (fastNlMeans), binarize (Sauvola), orientation (Tesseract OSD), border crop |
| Engine | Tesseract multi-PSM | Tesseract primary + pluggable cloud/handwriting engine (Google DocAI / Azure Read / TrOCR) for low-confidence pages |
| Tables | none | Camelot/`pdfplumber.extract_tables` + layout model for scanned labs |
| Output | flat text + 1 confidence | text + per-page + per-token confidence, bboxes, structured sections |
| Provenance | none | every extracted field carries `{page, bbox, char_span, confidence}` |
| Correction | none | editable preview UI writes back to `extractions` table |

## 3. Pipeline stages

```
            ┌─────────────────────────────────────────────────────────────┐
 Upload ──▶ │ 0. Ingest & secure (allow-list, size cap, AV scan, hash)    │
            ├─────────────────────────────────────────────────────────────┤
            │ 1. Classify container (pdf/img/docx/eml) + per-page type     │
            │    digital-PDF page  ─▶ pdfplumber text + tables             │
            │    scanned page/img  ─▶ go to stage 2                        │
            ├─────────────────────────────────────────────────────────────┤
            │ 2. Image preprocessing                                       │
            │    grayscale ▸ orientation(OSD) ▸ deskew ▸ denoise ▸         │
            │    contrast/CLAHE ▸ binarize(Sauvola) ▸ crop-borders ▸ upscale│
            ├─────────────────────────────────────────────────────────────┤
            │ 3. OCR engine selection                                      │
            │    printed  ─▶ Tesseract (multi-PSM, oem 1)                  │
            │    table     ─▶ layout + cell OCR                            │
            │    page conf < τ ─▶ fallback engine (cloud/TrOCR handwriting)│
            ├─────────────────────────────────────────────────────────────┤
            │ 4. Post-process: clean, merge pages, token confidences,      │
            │    low-confidence token spans flagged                        │
            ├─────────────────────────────────────────────────────────────┤
            │ 5. Structured extraction (doc-type templates)                │
            │    Lab │ Prescription │ Discharge │ Clinical-note schemas    │
            ├─────────────────────────────────────────────────────────────┤
            │ 6. Persist: raw_text, structured_json, confidence map,       │
            │    page images (encrypted) ▸ status=EXTRACTED                │
            └─────────────────────────────────────────────────────────────┘
                                   │
                       Human preview & correction (optional, required if conf<τ)
                                   │
                                   ▼  status=READY_FOR_CODING ─▶ NLP+coding
```

## 4. Confidence model
- **Page confidence** = mean Tesseract word conf (already estimated in `_tesseract_extract`).
- **Token confidence** = per-word conf from `image_to_data`; render spans `< 60%` highlighted in the correction UI.
- **Field confidence** = min(token confidences in the field's span) × extractor confidence.
- **Document confidence** = weighted mean of page confidences.
- **Routing rule:** `document_confidence < 0.70` **OR** any critical field (drug, dose, lab value) below 0.60 ⇒ force human correction before coding (`coder_review_required = true`).

## 5. Structured extractors (doc-type templates)
Each returns a typed object + provenance:
- **LabReport:** `[{analyte, value, unit, ref_range, flag(H/L), page, bbox}]`
- **Prescription:** `[{drug, strength, form, dose, frequency, duration, route}]` + prescriber, date
- **DischargeSummary:** `admission/discharge dates, diagnoses[], procedures[], medications[], follow_up`
- **ClinicalNote:** SOAP sections (Subjective/Objective/Assessment/Plan)

Doc type is detected (extend the existing `document_type` heuristic) and selects the template; unknown ⇒ generic section splitter.

## 6. Code changes from today
1. Extract OCR into a **worker job** (`tasks/extract.py`) invoked from a queue; `/api/documents/{id}/extract` enqueues, status via `GET /api/documents/{id}`.
2. Add `preprocess_v2()` with OpenCV: `deskew()`, `denoise()`, `orient_osd()`, `binarize_sauvola()`.
3. Return **per-token** confidences (`image_to_data` DICT) and persist a confidence map, not just a scalar.
4. Add `extract_tables()` for lab grids.
5. Add a **fallback engine interface** `OCREngine` (Tesseract impl now; cloud/handwriting impl later) selected when page conf < τ.
6. Persist results to `documents` + `extractions` tables (see schema) instead of returning ephemerally.
7. Add an **AV scan** + MIME allow-list + 25MB cap + content-hash dedupe at ingest.

## 7. Quality gates (see `10-EVALUATION-MATRIX.md`)
Track CER/WER on a labeled golden set, table-cell F1, field extraction F1, and % documents auto-routed to review. No OCR change ships if CER regresses > 1% on the golden set.
