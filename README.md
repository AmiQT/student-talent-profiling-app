# Student Talent Profiling App

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Astro](https://img.shields.io/badge/astro-%232C2052.svg?style=for-the-badge&logo=astro&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)

A platform for university students to build their talent profile, engage with ongoing programs and events, and connect with the university community.

Students create a profile, showcase their achievements and projects, join events, and interact through a social feed. The platform includes an AI assistant in Bahasa Melayu to help students navigate faculty info and university programs.

> **Security note:** this repository ships without secrets. Populate your own `.env` files before running any service. Never commit credentials.

---

## Features

| Feature | Description | Status |
| :--- | :--- | :--- |
| Student Profile | Build a talent profile with skills, achievements, projects, and experiences | Production |
| Showcase Feed | Post and share achievements like a social feed | Production |
| Event Program | Browse, register, and track university events (kokurikulum) | Production |
| AI Assistant | Voice-enabled chatbot in Bahasa Melayu with UTHM faculty context | Production |
| Talent Quiz | Discover strengths through a guided quiz | Production |
| Predictive Analytics | Risk and participation insights for university admin | Beta |
| PDF Reports | Auto-generated achievement reports for departments | Production |

---

## Gallery

| Mobile (Home) | AI Chat | Web Dashboard |
| :---: | :---: | :---: |
| ![Mobile Home](assets/mobile_home_demo.png) | ![AI Chat](assets/mobile_chat_demo.png) | ![Dashboard](assets/dashboard_demo.png) |

---

## Repository Layout

```
student-talent-profiling-app/
├── backend/                # FastAPI backend, AI agents, ML analytics
├── mobile_app/             # Flutter mobile app (student-facing)
├── web_dashboard_astro/    # Admin dashboard (Astro v5, university-facing)
├── assets/                 # Branding assets
└── .github/workflows/      # CI/CD pipelines
```

---

## System Architecture

```
Supabase (Auth + PostgreSQL + pgvector)
            |
            v
     FastAPI Backend  <---  AI Layer (Gemini 2.5 Flash + LangChain + RAG)
      |           |
      v           v
Flutter Mobile   Astro Web Dashboard
(students)       (university admin)
```

---

## Stack

| Layer | Technology |
| :--- | :--- |
| Mobile | Flutter, Dart 3, Provider, Supabase Flutter SDK |
| Backend | FastAPI, SQLAlchemy, Alembic, PyJWT |
| AI | Google Gemini 2.5 Flash, LangChain, LangGraph, RAG via pgvector |
| Dashboard | Astro v5, Tailwind v4, TypeScript, Chart.js |
| Database | Supabase (PostgreSQL + pgvector) |
| Media | Cloudinary |
| Payment | ToyyibPay |
| Deployment | Docker, Digital Ocean VPS, Vercel |

---

## Getting Started

### Backend

```bash
cd backend
cp .env.example .env   # fill in your values
python -m venv .venv
.venv\Scripts\activate  # Windows
pip install -r requirements.txt
python main.py          # http://localhost:8000
```

### Mobile App

```bash
cd mobile_app
cp assets/.env.example assets/.env   # fill in your values
flutter pub get
flutter run
```

### Web Dashboard

```bash
cd web_dashboard_astro
cp .env.example .env   # fill in your values
npm install
npm run dev            # http://localhost:4321
```

---

## Environment Variables

### Backend (`backend/.env`)

| Variable | Description |
| :--- | :--- |
| `DATABASE_URL` | Supabase PostgreSQL connection string |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_KEY` | Supabase anon key |
| `SUPABASE_SERVICE_KEY` | Supabase service role key |
| `SUPABASE_JWT_SECRET` | JWT secret (Project Settings > API) |
| `GEMINI_API_KEY` | Google Gemini API key |
| `CLOUDINARY_CLOUD_NAME` | Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | Cloudinary API secret |
| `ALLOWED_ORIGINS` | Comma-separated allowed CORS origins |

### Mobile App (`mobile_app/assets/.env`)

| Variable | Description |
| :--- | :--- |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon key |
| `BACKEND_URL` | Deployed backend URL |
| `CLOUDINARY_CLOUD_NAME` | Cloudinary cloud name |

### Web Dashboard (`web_dashboard_astro/.env`)

| Variable | Description |
| :--- | :--- |
| `PUBLIC_SUPABASE_URL` | Supabase project URL |
| `PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key |
| `PUBLIC_BACKEND_URL` | Deployed backend URL |

---

## License

MIT
