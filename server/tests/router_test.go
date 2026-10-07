package tests

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/eval"
	"mult-agent-madness/server/pkg/memory"
	"mult-agent-madness/server/pkg/models"
	"mult-agent-madness/server/pkg/router"
	"mult-agent-madness/server/pkg/vertex"
)

func setupTestServer(t *testing.T) (*router.Server, *router.Router, memory.Store) {
	t.Helper()
	cfg := &config.Config{
		ProjectID:          config.DefaultProjectID,
		Location:           config.DefaultLocation,
		ModelID:            config.ModelGeminiFlash,
		Port:               "8080",
		AuthMode:           "ADC",
		MaxBundleSizeBytes: config.MaxBundleSizeBytes,
	}

	store := memory.NewInMemoryStore()
	vClient, err := vertex.NewClient(cfg, nil)
	if err != nil {
		t.Fatalf("Failed to create vertex client: %v", err)
	}

	rater, err := eval.NewRater(cfg, vClient, "../shared/eval_benchmarks.json")
	if err != nil {
		t.Fatalf("Failed to create rater: %v", err)
	}

	srv := router.NewServer(cfg, vClient, store, rater)
	r := srv.SetupRouter()
	return srv, r, store
}

func TestHealthzEndpoint(t *testing.T) {
	_, r, _ := setupTestServer(t)

	req := httptest.NewRequest("GET", "/healthz", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d", w.Code)
	}

	var resp models.HealthResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if resp.Status != "healthy" {
		t.Errorf("Expected status healthy, got %s", resp.Status)
	}
	if resp.Model != config.ModelGeminiFlash {
		t.Errorf("Expected model %s, got %s", config.ModelGeminiFlash, resp.Model)
	}
	if resp.ProjectID != config.DefaultProjectID {
		t.Errorf("Expected project %s, got %s", config.DefaultProjectID, resp.ProjectID)
	}
	if resp.AuthMode != "ADC" {
		t.Errorf("Expected AuthMode ADC, got %s", resp.AuthMode)
	}
}

func TestModelInvariantStrictlyRejectsPro(t *testing.T) {
	// Invariant: NEVER use gemini-3.8-pro under any circumstances
	t.Setenv("VERTEX_MODEL_ID", config.ForbiddenModelPro)
	_, err := config.Load()
	if err == nil {
		t.Fatalf("Expected config.Load() to reject %s, but it succeeded", config.ForbiddenModelPro)
	}
	if !strings.Contains(err.Error(), "strictly forbidden") {
		t.Errorf("Unexpected error message: %v", err)
	}
}

func TestChatSSEStream(t *testing.T) {
	_, r, store := setupTestServer(t)

	payload := models.ChatRequest{
		Prompt:    "Explain Cloud Run PORT configuration",
		SessionID: "sess_stream_test",
		Stream:    true,
	}
	data, _ := json.Marshal(payload)

	req := httptest.NewRequest("POST", "/api/chat", bytes.NewReader(data))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d", w.Code)
	}

	body := w.Body.String()
	if strings.Contains(body, "event: error") {
		// Validates STRICT NEVER MOCK DIRECTIVE: true error surfaced directly instead of fake text
		if !strings.Contains(body, "Vertex AI streaming inference failed") {
			t.Errorf("Expected true Vertex error surfaced, got: %s", body)
		}
	} else {
		if !strings.Contains(body, "data: ") {
			t.Errorf("Expected SSE data lines, got: %s", body)
		}
		if !strings.Contains(body, "[DONE]") {
			t.Errorf("Expected [DONE] terminator, got: %s", body)
		}

		// Verify turn was persisted in store
		turns, err := store.GetEpisodicTurnsBySession(req.Context(), "sess_stream_test", 10)
		if err != nil || len(turns) == 0 {
			t.Fatalf("Expected turn to be saved in store, got turns: %v, err: %v", turns, err)
		}
		if turns[0].Route != models.RouteCloudEscalate {
			t.Errorf("Expected route %s, got %s", models.RouteCloudEscalate, turns[0].Route)
		}
	}
}

func TestMemoryIngestAndPIISanitization(t *testing.T) {
	_, r, store := setupTestServer(t)

	turn := models.EpisodicTurn{
		ID:             "turn_raw_pii",
		SessionID:      "sess_pii_test",
		UserPrompt:     "Contact alice@example.com or 555-0199 with token AIzaSyD9x82j19f8x7a6b5c4d3e2f1.",
		ModelResponse:  "Credentials noted.",
		Route:          models.RouteEdgeLocal,
		IsPIISanitized: false,
	}

	payload := models.MemoryIngestRequest{
		Turn: &turn,
	}
	data, _ := json.Marshal(payload)

	req := httptest.NewRequest("POST", "/api/memory/ingest", bytes.NewReader(data))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp models.MemoryIngestResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}
	if resp.IngestedCount != 1 {
		t.Errorf("Expected 1 ingested turn, got %d", resp.IngestedCount)
	}

	// Check stored turn for redaction
	saved, err := store.GetEpisodicTurn(req.Context(), "turn_raw_pii")
	if err != nil {
		t.Fatalf("Failed to retrieve stored turn: %v", err)
	}
	if strings.Contains(saved.UserPrompt, "alice@example.com") {
		t.Errorf("PII email was not sanitized: %s", saved.UserPrompt)
	}
	if strings.Contains(saved.UserPrompt, "AIzaSyD9x82j19f8x7a6b5c4d3e2f1") {
		t.Errorf("PII api_key was not sanitized: %s", saved.UserPrompt)
	}
	if !saved.IsPIISanitized {
		t.Errorf("Expected IsPIISanitized to be true")
	}
}

func TestCORSOptionsPreflight(t *testing.T) {
	_, r, _ := setupTestServer(t)

	req := httptest.NewRequest("OPTIONS", "/api/chat", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("Expected status 204 for OPTIONS, got %d", w.Code)
	}
	if w.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Errorf("Missing CORS header Access-Control-Allow-Origin")
	}
	if !strings.Contains(w.Header().Get("Access-Control-Allow-Methods"), "POST") {
		t.Errorf("Missing POST in Access-Control-Allow-Methods")
	}
}

func TestImageGenerateEndpoint(t *testing.T) {
	_, r, _ := setupTestServer(t)

	// 1. Verify OPTIONS Preflight
	optReq := httptest.NewRequest("OPTIONS", "/api/image/generate", nil)
	optW := httptest.NewRecorder()
	r.ServeHTTP(optW, optReq)

	if optW.Code != http.StatusNoContent {
		t.Fatalf("Expected status 204 for OPTIONS /api/image/generate, got %d", optW.Code)
	}

	// 2. Verify Empty Prompt Validation (400 Bad Request)
	badBody := bytes.NewBufferString(`{"prompt": ""}`)
	badReq := httptest.NewRequest("POST", "/api/image/generate", badBody)
	badReq.Header.Set("Content-Type", "application/json")
	badW := httptest.NewRecorder()
	r.ServeHTTP(badW, badReq)

	if badW.Code != http.StatusBadRequest {
		t.Fatalf("Expected status 400 for empty prompt, got %d", badW.Code)
	}

	// 3. Verify Malformed JSON Body (400 Bad Request)
	malformedReq := httptest.NewRequest("POST", "/api/image/generate", bytes.NewBufferString(`{invalid json`))
	malformedReq.Header.Set("Content-Type", "application/json")
	malformedW := httptest.NewRecorder()
	r.ServeHTTP(malformedW, malformedReq)

	if malformedW.Code != http.StatusBadRequest {
		t.Fatalf("Expected status 400 for malformed json, got %d", malformedW.Code)
	}
}

func TestModelWeightsEndpoint(t *testing.T) {
	_, r, _ := setupTestServer(t)

	// 1. Verify OPTIONS Preflight
	optReq := httptest.NewRequest("OPTIONS", "/api/weights/gemma-4-2b-it-int4.bin", nil)
	optW := httptest.NewRecorder()
	r.ServeHTTP(optW, optReq)

	if optW.Code != http.StatusNoContent {
		t.Fatalf("Expected status 204 for OPTIONS /api/weights/..., got %d", optW.Code)
	}
	if optW.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Errorf("Missing CORS header Access-Control-Allow-Origin")
	}

	// 2. Verify Missing Filename (400 Bad Request)
	emptyReq := httptest.NewRequest("GET", "/api/weights/", nil)
	emptyW := httptest.NewRecorder()
	r.ServeHTTP(emptyW, emptyReq)

	if emptyW.Code != http.StatusBadRequest {
		t.Fatalf("Expected status 400 for empty weights filename, got %d", emptyW.Code)
	}

	// 3. Verify Non-existent weights returns 404 with informative JSON error
	missingReq := httptest.NewRequest("GET", "/api/weights/nonexistent-model.bin", nil)
	missingW := httptest.NewRecorder()
	r.ServeHTTP(missingW, missingReq)

	if missingW.Code != http.StatusNotFound {
		t.Fatalf("Expected status 404 for missing weights file, got %d", missingW.Code)
	}
	var errResp map[string]string
	if err := json.NewDecoder(missingW.Body).Decode(&errResp); err != nil {
		t.Fatalf("Failed to decode JSON error: %v", err)
	}
	if !strings.Contains(errResp["error"], "nonexistent-model.bin") {
		t.Errorf("Expected error to contain model filename, got: %v", errResp)
	}
}

func TestFirebasePolicyEndpoint(t *testing.T) {
	_, r, _ := setupTestServer(t)

	req := httptest.NewRequest("GET", "/api/policy/firebase", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200 for Firebase policy, got %d", w.Code)
	}

	engineHeader := w.Header().Get("X-Firebase-Policy-Engine")
	if engineHeader != "RemoteConfig-v1.4.0" {
		t.Errorf("Expected X-Firebase-Policy-Engine RemoteConfig-v1.4.0, got: %s", engineHeader)
	}

	var policy map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&policy); err != nil {
		t.Fatalf("Failed to decode Firebase policy JSON: %v", err)
	}

	if policy["version"] != "1.4.0" {
		t.Errorf("Expected version 1.4.0, got: %v", policy["version"])
	}
	if policy["cloud_reasoning_model"] != "gemini-3.8-flash" {
		t.Errorf("Expected cloud_reasoning_model gemini-3.8-flash, got: %v", policy["cloud_reasoning_model"])
	}

	rules, ok := policy["rules"].([]interface{})
	if !ok || len(rules) == 0 {
		t.Fatalf("Expected non-empty rules list, got: %v", policy["rules"])
	}

	// Verify priority 100 rule is RULE_STRICT_PRIVACY
	firstRule := rules[0].(map[string]interface{})
	if firstRule["id"] != "RULE_STRICT_PRIVACY" {
		t.Errorf("Expected first rule to be RULE_STRICT_PRIVACY, got: %v", firstRule["id"])
	}
	if firstRule["route"] != "EDGE_LOCAL" {
		t.Errorf("Expected RULE_STRICT_PRIVACY route EDGE_LOCAL, got: %v", firstRule["route"])
	}
}

