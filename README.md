# Dobby — AI Home Inventory Agent

> **Google Cloud Rapid Agent Hackathon submission** · MongoDB Track

Dobby is an AI-powered home inventory system. This repo contains two AI agent workflows built on **Gemini**, **MongoDB Atlas**, and **Elastic Cloud**, deployed on **Google Cloud Run**.

**Live demo:** https://dobby-agent-172253357017.us-central1.run.app

---

## Agent Workflows

### 📷 Smart Intake Agent
Upload a photo of an item or a supermarket receipt. The agent:
1. Calls **Gemini Vision** to extract items (name, category, quantity, expiry date)
2. Fetches your home inventory from **MongoDB** to build cabinet context
3. Reasons over cabinet names, rooms, and content summaries to recommend the best cabinet for each item — using exact-match priority for known items, and Gemini multi-step reasoning for new ones
4. Returns a placement plan with cabinet, room, reason, and confidence per item
5. On confirmation, persists items to MongoDB and re-indexes Elastic for immediate discoverability

### 🔍 Inventory Discovery Agent
Ask any natural language question about your home inventory. The agent handles five query types:

| Query type | Example |
|------------|---------|
| Direct | "有牛奶吗" |
| Intent-based | "有吃的吗" / "什么可以喝" |
| Substitute | "有洗碗液吗" (finds 洗洁精) |
| Location | "厨房里有什么" |
| Expiry | "有快过期的食品吗" |

Pipeline: **Elastic** keyword search → full inventory fallback if no hits → **Gemini** reasons over candidates → structured response with location, match type, and explanation.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Web Demo UI                          │
│              (single-page HTML/JS)                      │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS
┌────────────────────────▼────────────────────────────────┐
│              FastAPI Backend (Cloud Run)                 │
│                                                         │
│  POST /intake/extract   → Gemini Vision                 │
│  POST /intake/plan      → Smart Intake Agent            │
│  POST /intake/confirm   → MongoDB + Elastic sync        │
│  POST /discovery        → Inventory Discovery Agent     │
│  POST /admin/seed       → Seed sample inventory         │
└──────────┬──────────────────┬───────────────────────────┘
           │                  │
┌──────────▼──────┐  ┌────────▼────────┐  ┌─────────────┐
│  MongoDB Atlas  │  │  Elastic Cloud  │  │  Vertex AI  │
│  (inventory     │  │  (full-text +   │  │  Gemini     │
│   store)        │  │   fuzzy search) │  │  2.5 Flash  │
└─────────────────┘  └─────────────────┘  └─────────────┘
```

**Tech stack:**
| Layer | Technology |
|-------|-----------|
| Backend | Python 3.13 · FastAPI · uvicorn |
| Primary data store | MongoDB Atlas (free tier) |
| Search | Elastic Cloud Serverless |
| AI | Gemini 2.5 Flash Lite (Vertex AI) |
| Auth | Application Default Credentials (ADC) |
| Hosting | Google Cloud Run |
| Demo UI | Single-page HTML/CSS/JS |

---

## Project Structure

```
Dobby/
├── agent/                  # FastAPI backend
│   ├── agents/
│   │   ├── intake_agent.py       # Smart Intake Agent logic
│   │   └── discovery_agent.py    # Inventory Discovery Agent logic
│   ├── services/
│   │   ├── gemini_service.py     # Vertex AI / Gemini calls
│   │   ├── mongo_service.py      # MongoDB Atlas client
│   │   └── elastic_service.py    # Elastic Cloud client
│   ├── tests/
│   │   ├── test_intake_agent.py       # 10 unit tests
│   │   ├── test_discovery_agent.py    # 13 unit tests
│   │   ├── test_intake_endpoints.py   # 5 integration tests
│   │   └── test_discovery_endpoints.py # 4 integration tests
│   ├── main.py             # FastAPI app + endpoints
│   └── requirements.txt
├── web/
│   └── index.html          # Demo UI
├── Dockerfile              # Cloud Run container
├── Dobby/                  # iOS app (SwiftUI + Core Data + CloudKit)
└── README.md
```

---

## Running Locally

### Prerequisites
- Python 3.13
- MongoDB Atlas cluster (free tier)
- Elastic Cloud Serverless deployment
- Google Cloud project with Vertex AI enabled
- `gcloud` CLI authenticated

### Setup

```bash
# Clone
git clone https://github.com/frodo9999/Dobby.git
cd Dobby/agent

# Install dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your MongoDB URI, Elastic endpoint, and Elastic API key

# Authenticate with Google Cloud
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_PROJECT_ID

# Start server
uvicorn main:app --reload --port 8000
```

### Seed sample inventory
```bash
curl -X POST http://localhost:8000/admin/seed
```

### Run tests
```bash
pytest tests/test_intake_agent.py tests/test_discovery_agent.py -v
```

---

## Deploying to Cloud Run

```bash
# From project root
gcloud run deploy dobby-agent \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "MONGODB_URI=...,ELASTIC_ENDPOINT=...,ELASTIC_API_KEY=...,GCP_PROJECT_ID=...,GCP_LOCATION=us-central1"
```

---

## iOS App

The `Dobby/` folder contains the companion iOS app (SwiftUI + Core Data + CloudKit). It uses the same Gemini Vision integration for on-device photo-based item recognition. The iOS app and the agent backend are independent — the iOS app uses CloudKit for sync while the backend uses MongoDB + Elastic for the hackathon demo.

---

## License

MIT License — see [LICENSE](LICENSE)
