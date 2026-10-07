---
name: fullstack-cloudrun-deploy
description: Build, deploy, verify, and teardown full-stack distributed applications on Google Cloud Run and Vertex AI. Enforces ADC authentication, live HTTP verification probes, zero-secret security, and post-execution ephemeral resource teardown.
---

# Full-Stack Cloud Run Deployment & Verification Standard

This skill establishes the mandatory protocol for building, deploying, testing, and verifying full-stack Flutter Web and Go microservices on Google Cloud Run in project `${GCP_PROJECT}` (default: `davenport-boutique`, region: `us-central1`).

---

## 1. Foundational Invariant

> **"A task involving services or web applications is NOT complete until built, deployed to Cloud Run ('$GCP_PROJECT'), and verified via live HTTP probe. Always provide the live service URL."**

No task, feature, or bugfix touching client UI, switching routers, or backend APIs may be declared done based solely on local unit tests or localhost runs. Work is complete only when the live production URL responds with HTTP 200 and passes functional probes.

---

## 2. Cloud Environment & Authentication Standards

1. **Application Default Credentials (ADC)**:
   - Always rely on Google Cloud ADC (`gcloud auth application-default print-access-token` / metadata server).
   - **Never require, prompt for, or check for a `GEMINI_API_KEY`**.
2. **Project & Regions**:
   - Project: `davenport-boutique` (or value of `$GCP_PROJECT`).
   - Cloud Run Services: `us-central1`.
   - Vertex AI Location: `us-central1` or `global` (Gemini 3.8 models require `LOCATION="global"` or `"us"` / `"us-central1"`).
   - Vertex Staging Bucket: `gs://${GCP_PROJECT}-vertex-staging/`.
3. **Zero Secrets in Repository**:
   - Never commit API keys, service account JSON files, or internal domains to git or docs.

---

## 3. Production Deployment Workflow

### Phase 1: Build & Deploy Go Backend Microservice
```bash
# Source environment variables if .env is present
[ -f .env ] && set -a && source .env && set +a

# Deploy Go Cloud Run service
gcloud run deploy distributed-ai-backend \
  --source ./server \
  --region us-central1 \
  --project "${GCP_PROJECT}" \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars LOCATION=global,VERTEX_LOCATION=global,VERTEX_MODEL_ID=gemini-3.8-flash,AUTH_MODE=adc
```

### Phase 2: Compile & Deploy Flutter Web Client
```bash
# 1. Compile release web assets with CanvasKit / WASM support
cd client && ../scripts/flutter build web --release

# 2. Deploy static web server to Cloud Run
gcloud run deploy distributed-ai-frontend \
  --source . \
  --region us-central1 \
  --project "${GCP_PROJECT}" \
  --platform managed \
  --allow-unauthenticated
```

---

## 4. Mandatory Live Verification Probes

Immediately following deployment, run automated HTTP probes against the live Cloud Run URLs:

```bash
BACKEND_URL=$(gcloud run services describe distributed-ai-backend --region us-central1 --project "${GCP_PROJECT}" --format 'value(status.url)')
FRONTEND_URL=$(gcloud run services describe distributed-ai-frontend --region us-central1 --project "${GCP_PROJECT}" --format 'value(status.url)')

# Probe 1: Healthcheck & Model Invariant Validation
curl -s -i "${BACKEND_URL}/healthz"
# Must return HTTP 200 with {"status":"ok","model":"gemini-3.8-flash"}

# Probe 2: Memory Edge Bundle Invariant (< 50 KB check)
curl -s -i "${BACKEND_URL}/api/memory/bundle"
# Must return HTTP 200 with size_bytes < 51200

# Probe 3: Live Gemini 3.8 Flash Chat Stream
curl -s -i -X POST "${BACKEND_URL}/api/chat" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Summarize system architecture in one sentence.", "session_id": "probe_test"}'
# Must return HTTP 200 and valid JSON turn response

# Probe 4: Live Frontend Headers (COOP / COEP for WebGPU & SharedArrayBuffer)
curl -s -i "${FRONTEND_URL}/"
# Must return HTTP 200 with:
# cross-origin-embedder-policy: credentialless (or require-corp)
# cross-origin-opener-policy: same-origin
```

---

## 5. Ephemeral Resource Teardown Protocol

All benchmarks, integration tests, or evaluation runs that stage temporary blobs or create ephemeral resources must clean up afterward:

```bash
# Execute post-deployment and post-eval teardown script
bash scripts/teardown_eval_resources.sh
```

The script verifies and prunes:
- Temporary benchmark files in `gs://${GCP_PROJECT}-vertex-staging/evals/`.
- Local scratch directories and ephemeral test tokens.
