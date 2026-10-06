# Distributed AI Platform: Edge-to-Cloud Orchestration & Durable Memory

[![Go Tests](https://img.shields.io/badge/go-1.22+-blue.svg)](server/)
[![Flutter](https://img.shields.io/badge/flutter-3.24+-02569B.svg)](client/)
[![Terraform](https://img.shields.io/badge/terraform->=1.5.0-844FBA.svg)](terraform/)
[![Cloud Run](https://img.shields.io/badge/deploy-Cloud%20Run-4285F4.svg)](https://cloud.google.com/run)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)

A production-grade, distributed AI platform demonstrating dynamic routing between on-device edge models (**Gemma 4** int4 via WebGPU and Android LiteRT, and **Gemini Nano** via Chrome Prompt API) and cloud reasoning (**Gemini 3.8 Flash** and **Nano Banana 2 Lite** multimodal synthesis on Google Cloud Run via Vertex AI).

---

## Architecture Overview

```
                      +------------------------------------------+
                      |         Flutter Client Workspace         |
                      |  - Academic / Sepia 3-Panel Layout       |
                      |  - LoreCraft Living Dynamic Game World   |
                      |  - Model Test Bench & LLM-as-a-Rater     |
                      +--------------------+---------------------+
                                           |
                                           v
                      +------------------------------------------+
                      |      Switching Router (Firebase AI)      |
                      |  - PII Detection & Edge-Local Redaction  |
                      |  - Token Budget & Latency Optimization   |
                      |  - Circuit Breaker Fallback Logic        |
                      +---------+----------------------+---------+
                                |                      |
         [Sensitive / Fast /    |                      | [Complex Synthesis /
          Offline / Sub-60ms]   |                      |  Multimodal / >4k tokens]
                                v                      v
     +----------------------------------+   +------------------------------------+
     |      On-Device Local Engine      |   |       Google Cloud Platform        |
     |  - Gemma 4 int4 (WebGPU / WASM)  |   |  - Go Backend (Cloud Run v2)       |
     |  - LiteRT-LM (Android Emulator)  |   |  - Vertex AI (Gemini 3.8 Flash)    |
     |  - Gemini Nano (Chrome Built-in) |   |  - Nano Banana 2 Lite (Images)     |
     |  - 0 KB Cloud Egress             |   |  - Cloud Firestore (Durable Graph) |
     +-----------------+----------------+   +-----------------+------------------+
                       |                                      |
                       +-------------------+------------------+
                                           |
                                           v
                      +------------------------------------------+
                      |       Dual-Loop Memory Architecture      |
                      |  - Online: SQLite / IndexedDB Context    |
                      |  - Offline: Cloud Run Consolidator       |
                      |  - Edge Bundle: Strict < 50 KB Budget    |
                      +------------------------------------------+
```

### Key Capabilities
- **Zero-Cloud Egress Edge Turns**: Quantized **Gemma 4 2B/4B** int4 models run client-side in Chrome WebGPU (or Android LiteRT CPU fallback) for sub-60ms TTFT, zero egress cost, and total privacy for sensitive PII.
- **Dynamic Cloud Escalation**: Deep architectural multi-hop synthesis queries stream from **Gemini 3.8 Flash** on Cloud Run over Server-Sent Events (SSE).
- **Multimodal Visual Synthesis**: On-demand game canvas and visual generation powered by **Nano Banana 2 Lite** (`gemini-3.1-flash-lite-image`) on Cloud Run.
- **Dual-Loop Durable Memory**: Real-time client working memory (Online Loop) automatically syncs sanitized episodes to Cloud Run for asynchronous consolidation and contradiction resolution via Gemini 3.8 Flash (Offline Loop), indexing into Firestore and publishing compact edge memory bundles (< 50 KB).
- **LLM-as-a-Rater Benchmarks**: Automated objective scoring harness comparing edge candidate outputs against golden cloud references across Semantic Fidelity, Instruction Compliance, Safety/PII Redaction, and Latency Efficiency.
- **LoreCraft Living World Studio**: Tangible distributed gaming studio showcasing reactive edge NPC dialogue, cross-faction campaign synthesis, dynamic 3-card next-turn generation, and live Canon Arbiter scorecards.

---

## Directory Layout

```
mult-agent-madness/
├── .env.example              # Environment variables template (no secrets)
├── package.json              # NPM automation shortcuts
├── start_emulator.sh         # One-click Android emulator & app launcher
├── client/                   # Flutter cross-platform client (Web WASM & Android)
│   ├── lib/                  # Dart application source (Sepia 3-panel layout)
│   ├── test/                 # 65+ unit, widget, and integration tests
│   └── web/                  # Web entrypoint, WebGPU & Chrome Prompt API bridges
├── server/                   # Golang Cloud Run v2 backend service
│   ├── cmd/server/           # Backend entrypoint (HTTP REST & SSE streams)
│   ├── pkg/config/           # Dynamic config & .env loader
│   ├── pkg/memory/           # Offline memory consolidator & edge bundle packer
│   ├── pkg/vertex/           # Vertex AI client (Gemini 3.8 Flash / ADC auth)
│   └── tests/                # Backend unit tests and LLM-as-a-Rater harness
├── shared/                   # Shared JSON contracts & schemas
│   ├── routing_policy.json   # Dynamic switching policy schema
│   ├── memory_schema.json    # Durable knowledge graph & edge bundle schema
│   └── eval_benchmarks.json  # Canonical rater test suites & golden references
├── terraform/                # Infrastructure as Code (Cloud Run, Firestore, GCS)
│   ├── main.tf               # Cloud Run v2, Firestore Native, Artifact Registry
│   ├── variables.tf          # Parameter declarations
│   └── terraform.tfvars.example # Environment variable template
├── scripts/                  # Automated toolchain wrappers & lifecycle scripts
│   ├── flutter / dart        # Hermetic Flutter/Dart invocation wrappers
│   ├── setup_android_sdk.sh  # Android SDK & cmdline-tools setup
│   ├── create_gemma_avd.sh   # Tuned ARM64 Gemma 4 Android Virtual Device
│   ├── run_android_emulator.sh # Boots emulator, compiles & launches app
│   └── teardown_eval_resources.sh # Ephemeral GCS benchmark pruning
└── docs/                     # Continuous Doc-Code-Test Parity Reference Guides
    ├── architecture.md       # Edge-to-cloud architecture specification
    ├── model_matrix.md       # Hardware execution matrix & constraints
    ├── memory_pipeline.md    # Online/offline memory sequence diagrams
    ├── routing_guide.md      # Dynamic switching router rules & circuit breaker
    ├── eval_rater_guide.md   # LLM-as-a-Rater benchmark specifications
    └── walkthrough.md        # Comprehensive deployment and verification runbook
```

---

## Prerequisites

| Tool | Version | Required For |
| :--- | :--- | :--- |
| **Google Cloud SDK (`gcloud`)** | Latest | GCP authentication, Cloud Run deployment, Vertex AI |
| **Go** | `>= 1.22` | Backend server, consolidator, and eval suite |
| **Terraform** | `>= 1.5.0` | GCP infrastructure provisioning |
| **Flutter SDK** | `>= 3.24` (Dart `>= 3.5`) | Client application (`scripts/flutter` provided) |
| **Node.js & npm** | `>= 18.0` | Optional convenience script runner (`npm run ...`) |
| **Java JDK** | `17` | Optional: Android emulator and APK compilation |
| **Android SDK** | API 34+ | Optional: Android emulator (`scripts/setup_android_sdk.sh`) |

---

## Manual Steps Required (First-Time Setup)

Before running or deploying the application, perform these one-time manual configuration steps:

### 1. Google Cloud Authentication & Application Default Credentials (ADC)
The backend uses Google Cloud Application Default Credentials (ADC) to interact with Vertex AI (`Gemini 3.8 Flash`) and Cloud Firestore. **No API key is required.**

```bash
# Log in to Google Cloud CLI
gcloud auth login

# Generate local Application Default Credentials (ADC) for Vertex AI SDK
gcloud auth application-default login

# Set your active GCP project
gcloud config set project <your-gcp-project-id>
```

### 2. Enable Required Google Cloud APIs
Enable the required services in your target GCP project:

```bash
gcloud services enable \
  run.googleapis.com \
  aiplatform.googleapis.com \
  firestore.googleapis.com \
  artifactregistry.googleapis.com \
  storage.googleapis.com \
  cloudbuild.googleapis.com
```

### 3. Provision Cloud Firestore (Native Mode)
The durable memory pipeline requires Cloud Firestore in Native mode:

```bash
# Create a Native Firestore database if one does not already exist
gcloud firestore databases create --location=us-central1 --type=firestore-native
```
*(If a database already exists in your project, verify its mode is Native under Cloud Console > Firestore).*

### 4. Configure Environment Variables (`.env`)
Create your local environment file from the provided template:

```bash
cp .env.example .env
```

Open `.env` and set your project parameters:
```dotenv
GCP_PROJECT=your-gcp-project-id
PROJECT_ID=your-gcp-project-id
GCP_REGION=us-central1
LOCATION=global
VERTEX_LOCATION=global
VERTEX_MODEL_ID=gemini-3.8-flash
CLOUD_BACKEND_URL=http://localhost:8080
PORT=8080
```
> **Security Note:** The `.env` file is explicitly ignored by `.gitignore` and must never be checked into version control. Never place service account keys or raw API tokens in tracked files.

### 5. (Optional) Accept Android SDK Licenses
If you plan to run the Android Emulator:

```bash
# Ensure ANDROID_HOME is exported
export ANDROID_HOME="${HOME}/Library/Android/sdk"
export PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

# Accept all Android SDK licenses
yes | sdkmanager --licenses
```

### 6. (Optional) Enable Chrome Built-in AI (Gemini Nano)
To test Gemini Nano directly inside Google Chrome:
1. Open Google Chrome (v128+).
2. Navigate to `chrome://flags/#prompt-api-for-gemini-nano` (or `#prompt-api`).
3. Set the flag to **Enabled**.
4. Relaunch Chrome.
5. Ensure your workstation drive has at least **22 GB** free space for the model weights.

---

## Installation & Local Execution

### Step 1: Provision Infrastructure via Terraform (Optional)
To provision Cloud Run, Artifact Registry, Firestore, and GCS buckets using Terraform:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Update project_id in terraform.tfvars

terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
cd ..
```

### Step 2: Run the Golang Backend Locally
The backend serves the REST API, SSE chat streaming, memory ingestion, offline consolidator, and LLM-as-a-Rater benchmark:

```bash
cd server
go run cmd/server/main.go
```

Verify backend health in a separate terminal:
```bash
curl -s http://localhost:8080/healthz | jq .
# Expected output: {"status":"ok","model":"gemini-3.8-flash","timestamp":"..."}
```

### Step 3: Run the Flutter Web Client
Launch the client in Google Chrome:

```bash
cd client

# Fetch dependencies
../scripts/flutter pub get

# Run on Chrome with WebGPU and backend URL defined
../scripts/flutter run -d chrome \
  --web-renderer canvaskit \
  --dart-define=CLOUD_BACKEND_URL=http://localhost:8080
```

The web application opens at `http://localhost:random_port/` with full WebGPU hardware acceleration.

### Step 4: Run the Android Emulator (Alternative Edge Platform)
To run on a tuned ARM64 Android Virtual Device:

```bash
# Convenience one-line boot script:
./start_emulator.sh

# Or using the granular step script:
bash scripts/setup_android_sdk.sh
bash scripts/create_gemma_avd.sh gemma4_edge_tablet
bash scripts/run_android_emulator.sh gemma4_edge_tablet http://localhost:8080
```

---

## Testing & Verification Suite

All tests can be executed locally without external cloud dependencies:

### 1. Backend Go Tests
Verifies offline memory consolidation, strict 50 KB edge bundle packing, episodic turn concurrency, and LLM-as-a-Rater parsing:

```bash
cd server
go test -v ./...
cd ..
```

### 2. Frontend Flutter Tests
Comprehensive 65-test suite covering Switching Router, PII scrubber, LoreCraft World Engine, Canon Arbiter, and A2UI dynamic surface rendering:

```bash
cd client
../scripts/flutter test test/all_tests.dart
cd ..
```

### 3. LLM-as-a-Rater Benchmark Verification
Run the automated scenario benchmark evaluator:

```bash
cd server
go test -v ./tests -run TestScenarioPromptsWithRater
cd ..
```

### 4. Terraform Validation
Ensure infrastructure code meets formatting and provider standards:

```bash
cd terraform
terraform fmt -check
terraform validate
cd ..
```

---

## Production Deployment to Google Cloud Run

Both frontend and backend services deploy seamlessly to Google Cloud Run in project `${GCP_PROJECT}`:

### 1. Deploy the Backend Service
```bash
# Load environment parameters
[ -f .env ] && set -a && source .env && set +a

# Deploy Go backend to Cloud Run
gcloud run deploy distributed-ai-backend \
  --source ./server \
  --region us-central1 \
  --project "${GCP_PROJECT}" \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars LOCATION=global,VERTEX_LOCATION=global,VERTEX_MODEL_ID=gemini-3.8-flash,AUTH_MODE=adc
```

Capture the deployed service URL (e.g. `https://distributed-ai-backend-<hash>-uc.a.run.app`).

### 2. Deploy the Frontend Client
```bash
# Build production web bundle with Cloud Run backend URL injected
cd client
../scripts/flutter build web --release --dart-define=CLOUD_BACKEND_URL="${CLOUD_BACKEND_URL}"

# Deploy static web server to Cloud Run
gcloud run deploy distributed-ai-frontend \
  --source . \
  --region us-central1 \
  --project "${GCP_PROJECT}" \
  --platform managed \
  --allow-unauthenticated
cd ..
```

### 3. Live HTTP Verification Probes
Verify live endpoints using HTTP probes:

```bash
# Probe 1: Healthcheck
curl -s -i "${CLOUD_BACKEND_URL}/healthz"

# Probe 2: Memory Edge Bundle (< 50 KB budget verification)
curl -s -i "${CLOUD_BACKEND_URL}/api/memory/bundle"

# Probe 3: Live Gemini 3.8 Flash Chat Stream
curl -s -i -X POST "${CLOUD_BACKEND_URL}/api/chat" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Summarize the durable memory policy.", "session_id": "test_session"}'

# Probe 4: Live Frontend Web App (Security Headers)
curl -s -i "${FRONTEND_URL}/"
```

---

## Resource Lifecycle & Teardown

To ensure no orphaned test resources or ephemeral storage blobs remain in your Google Cloud project after benchmarking:

```bash
bash scripts/teardown_eval_resources.sh
```

This automated teardown script safely prunes:
- Ephemeral benchmark evaluation outputs under `gs://${EVAL_BUCKET}/evals/`.
- Temporary local evaluation artifacts in `server/tmp_evals/`.

To destroy all Terraform-managed cloud resources:
```bash
cd terraform
terraform destroy
cd ..
```

---

## Documentation Index

Detailed architectural specifications and deep-dive guides are available in [`docs/`](docs/):
- [Architecture Guide](docs/architecture.md): Complete system overview and edge-cloud topology.
- [Model Matrix & Constraints](docs/model_matrix.md): Hardware specs, context sizes, and TTFT benchmarks.
- [Memory Pipeline Specification](docs/memory_pipeline.md): Online/offline durable memory synchronization loops.
- [Routing & Circuit Breaker Guide](docs/routing_guide.md): Firebase AI dynamic switching policy.
- [LLM-as-a-Rater Guide](docs/eval_rater_guide.md): Automated evaluation rubrics, dimensions, and scoring.
- [Deployment Walkthrough & Runbook](docs/walkthrough.md): Comprehensive step-by-step production runbook.
