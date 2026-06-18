# 🏥 MedCode AI

**Clinical documentation intelligence** — converts prescriptions, lab reports, discharge
summaries, scanned documents, and clinical notes into **validated ICD-10 coding suggestions**
with evidence, confidence, and anti-hallucination safeguards.

Pipeline: **OCR → Medical NLP → BM25 retrieval (verified ICD-10) → constrained LLM
reasoning → DB validation → drug-interaction & abnormal-lab checks → coding report.**

---

## 📦 Repository layout
```
docs/                        ★ Production launch blueprint (read docs/README.md first)
backend/db/schema_v3.sql     Production PostgreSQL schema (target data model)
medcode-v2-persistent.zip    Current prototype source (Flask backend + React frontend)
```
> The prototype source currently ships inside `medcode-v2-persistent.zip`. **First
> maintainer steps:** (1) rotate the leaked secrets and purge history (see below),
> (2) extract the archive into `backend/` and `frontend/`, (3) follow the roadmap.

## 🚦 Project status
This is a **strong prototype**, not yet launch-ready for regulated buyers. The clinical
core is solid; platform, workflow, compliance, reliability and measurement are the work
ahead. See the brutally honest **[Production Readiness Assessment](docs/00-PRODUCTION-READINESS-ASSESSMENT.md)**
and the full **[blueprint](docs/README.md)**.

> ⚠️ **Security note (action required):** the prototype archive contains a real
> `backend/.env` with **live-looking API keys** (Groq, Razorpay, Gmail app password,
> JWT secret). **Rotate all of them now** and purge them from git history
> (`git filter-repo`). A `.gitignore` is included so extracted `.env` files are never
> committed again. See [docs/08-SECURITY-PLAN.md](docs/08-SECURITY-PLAN.md).

## ▶️ Run locally (prototype)
After extracting the archive:
```bash
# Backend
cd backend
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env        # add your OWN GROQ_API_KEY + a strong JWT_SECRET
python app.py               # http://localhost:5000  (needs Tesseract + poppler)

# Frontend
cd frontend && npm install && npm run dev          # http://localhost:3000
```

## ⚖️ Clinical disclaimer
MedCode AI provides **assistive coding suggestions only**. All output must be verified by a
certified medical coder (CCS/CPC) and treating clinician. It is not a medical device and
does not provide medical advice.

## 📚 Blueprint
Start here → **[docs/README.md](docs/README.md)**
