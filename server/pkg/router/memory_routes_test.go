package router

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/memory"
	"mult-agent-madness/server/pkg/models"
	"mult-agent-madness/server/pkg/vertex"
)

func setupMemoryTestServer(t *testing.T) (*Server, *Router, memory.Store) {
	t.Helper()
	cfg := &config.Config{
		ProjectID:          config.DefaultProjectID,
		Location:           config.DefaultLocation,
		ModelID:            config.ModelGeminiFlash,
		Port:               "8080",
		AuthMode:           "ADC",
		MaxBundleSizeBytes: config.MaxBundleSizeBytes, // 51200 bytes
	}

	store := memory.NewInMemoryStore()
	vClient, err := vertex.NewClient(cfg, nil)
	if err != nil {
		t.Fatalf("Failed to create vertex client: %v", err)
	}

	srv := NewServer(cfg, vClient, store, nil)
	r := srv.SetupRouter()
	return srv, r, store
}

func TestHandleMemoryIngest_FlatJSON(t *testing.T) {
	_, r, store := setupMemoryTestServer(t)

	flatTurn := map[string]interface{}{
		"id":             "turn_flat_01",
		"session_id":     "sess_flat_test",
		"user_prompt":    "Architectural decision: Use SQLite on edge and Firestore in cloud.",
		"model_response": "Acknowledged. Dual-loop memory configured.",
		"route":          models.RouteEdgeLocal,
		"consolidated":   true,
	}
	body, err := json.Marshal(flatTurn)
	if err != nil {
		t.Fatalf("Failed to marshal flat turn: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/api/memory/ingest", bytes.NewReader(body))
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

	if resp.Status != "success" {
		t.Errorf("Expected status success, got %s", resp.Status)
	}
	if resp.IngestedCount != 1 {
		t.Fatalf("Expected IngestedCount 1, got %d", resp.IngestedCount)
	}
	if len(resp.TurnIDs) != 1 || resp.TurnIDs[0] != "turn_flat_01" {
		t.Errorf("Expected TurnIDs ['turn_flat_01'], got %v", resp.TurnIDs)
	}

	// Verify persistence and consolidated status in store
	saved, err := store.GetEpisodicTurn(context.Background(), "turn_flat_01")
	if err != nil {
		t.Fatalf("Failed to retrieve stored turn: %v", err)
	}
	if saved.UserPrompt != flatTurn["user_prompt"] {
		t.Errorf("Expected user_prompt %s, got %s", flatTurn["user_prompt"], saved.UserPrompt)
	}
	if !saved.Consolidated {
		t.Errorf("Expected turn to be marked consolidated")
	}
}

func TestHandleMemoryIngest_SingleTurnEnvelope(t *testing.T) {
	_, r, store := setupMemoryTestServer(t)

	turn := models.EpisodicTurn{
		ID:             "turn_single_02",
		SessionID:      "sess_single_test",
		UserPrompt:     "Secret key is AIzaSyD9x82j19f8x7a6b5c4d3e2f1 and contact is test@example.com",
		ModelResponse:  "Stored securely.",
		Route:          models.RouteEdgeLocal,
		IsPIISanitized: false,
	}

	envelope := models.MemoryIngestRequest{
		Turn: &turn,
	}
	body, err := json.Marshal(envelope)
	if err != nil {
		t.Fatalf("Failed to marshal single turn envelope: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/api/memory/ingest", bytes.NewReader(body))
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
		t.Errorf("Expected IngestedCount 1, got %d", resp.IngestedCount)
	}

	// Verify PII redaction on ingest
	saved, err := store.GetEpisodicTurn(context.Background(), "turn_single_02")
	if err != nil {
		t.Fatalf("Failed to retrieve stored turn: %v", err)
	}
	if strings.Contains(saved.UserPrompt, "test@example.com") {
		t.Errorf("Email was not sanitized: %s", saved.UserPrompt)
	}
	if strings.Contains(saved.UserPrompt, "AIzaSyD9x82j19f8x7a6b5c4d3e2f1") {
		t.Errorf("API key was not sanitized: %s", saved.UserPrompt)
	}
	if !saved.IsPIISanitized {
		t.Errorf("Expected IsPIISanitized to be true")
	}
}

func TestHandleMemoryIngest_BatchTurnsEnvelope(t *testing.T) {
	_, r, store := setupMemoryTestServer(t)

	turns := []models.EpisodicTurn{
		{
			ID:            "turn_batch_01",
			SessionID:     "sess_batch_test",
			UserPrompt:    "First turn in batch",
			ModelResponse: "First response",
			Route:         models.RouteEdgeLocal,
			Consolidated:  false,
		},
		{
			ID:            "turn_batch_02",
			SessionID:     "sess_batch_test",
			UserPrompt:    "Second turn in batch",
			ModelResponse: "Second response",
			Route:         models.RouteEdgeLocal,
			Consolidated:  true,
		},
	}

	envelope := models.MemoryIngestRequest{
		Turns: turns,
	}
	body, err := json.Marshal(envelope)
	if err != nil {
		t.Fatalf("Failed to marshal batch turns envelope: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/api/memory/ingest", bytes.NewReader(body))
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

	if resp.IngestedCount != 2 {
		t.Fatalf("Expected IngestedCount 2, got %d", resp.IngestedCount)
	}

	// Verify both turns persisted and consolidated status respected
	saved1, err := store.GetEpisodicTurn(context.Background(), "turn_batch_01")
	if err != nil || saved1.Consolidated {
		t.Errorf("Expected turn_batch_01 to NOT be consolidated, got: %v, err: %v", saved1, err)
	}

	saved2, err := store.GetEpisodicTurn(context.Background(), "turn_batch_02")
	if err != nil || !saved2.Consolidated {
		t.Errorf("Expected turn_batch_02 to be marked consolidated, got: %v, err: %v", saved2, err)
	}
}

func TestHandleMemoryBundle_Packing(t *testing.T) {
	_, r, store := setupMemoryTestServer(t)
	ctx := context.Background()

	// Seed durable knowledge nodes
	nodes := []*models.DurableKnowledgeNode{
		{
			ID:                     "node_arch_01",
			EntityName:             "Dual-Loop Memory",
			Category:               models.CategorySystemArchitecture,
			Summary:                "Edge SQLite for working context, Cloud Firestore for consolidated knowledge.",
			Confidence:             0.98,
			ResolvedContradictions: []string{"Local-only vs Dual-loop"},
			LastUpdated:            "2026-10-07T00:00:00Z",
		},
		{
			ID:          "node_pref_01",
			EntityName:  "User Model Preference",
			Category:    models.CategoryUserPreference,
			Summary:     "Prefers Gemini 3.8 Flash for reasoning and Gemma 4 for edge.",
			Confidence:  0.95,
			LastUpdated: "2026-10-07T00:00:00Z",
		},
	}

	for _, n := range nodes {
		if err := store.SaveKnowledgeNode(ctx, n); err != nil {
			t.Fatalf("Failed to save knowledge node: %v", err)
		}
	}

	req := httptest.NewRequest(http.MethodGet, "/api/memory/bundle", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	// Verify headers
	if ct := w.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
		t.Errorf("Expected Content-Type application/json, got %s", ct)
	}
	if sizeHeader := w.Header().Get("X-Bundle-Size-Bytes"); sizeHeader == "" {
		t.Errorf("Missing X-Bundle-Size-Bytes header")
	}
	if countHeader := w.Header().Get("X-Bundle-Anchors-Count"); countHeader != "2" {
		t.Errorf("Expected X-Bundle-Anchors-Count '2', got %s", countHeader)
	}

	var bundle models.CompactEdgeMemoryBundle
	if err := json.NewDecoder(w.Body).Decode(&bundle); err != nil {
		t.Fatalf("Failed to decode bundle response: %v", err)
	}

	if bundle.BundleVersion != 1 {
		t.Errorf("Expected BundleVersion 1, got %d", bundle.BundleVersion)
	}
	if bundle.TotalAnchors != 2 {
		t.Errorf("Expected TotalAnchors 2, got %d", bundle.TotalAnchors)
	}
	if len(bundle.Anchors) != 2 {
		t.Fatalf("Expected 2 anchors in bundle, got %d", len(bundle.Anchors))
	}

	// Verify distillation contains resolved contradictions
	foundContradiction := false
	for _, anchor := range bundle.Anchors {
		if anchor.AnchorID == "node_arch_01" {
			if !strings.Contains(anchor.DistilledContext, "[Resolved: Local-only vs Dual-loop]") {
				t.Errorf("Expected resolved contradiction in distilled context, got: %s", anchor.DistilledContext)
			}
			foundContradiction = true
		}
	}
	if !foundContradiction {
		t.Errorf("Expected node_arch_01 in anchors")
	}

	// Enforce hard size limit < 51200 bytes
	if bundle.SizeBytes > config.MaxBundleSizeBytes {
		t.Errorf("Bundle size %d exceeded %d bytes limit", bundle.SizeBytes, config.MaxBundleSizeBytes)
	}
}

func TestHandleMemoryBundle_Strict50KBLimit(t *testing.T) {
	_, r, store := setupMemoryTestServer(t)
	ctx := context.Background()

	// Inject 250 heavy nodes exceeding 50 KB
	for i := 1; i <= 250; i++ {
		node := &models.DurableKnowledgeNode{
			ID:          fmt.Sprintf("node_heavy_%03d", i),
			EntityName:  fmt.Sprintf("Heavy Architectural Node %d with Extensive Context", i),
			Category:    models.CategoryRoadmapDecision,
			Summary:     fmt.Sprintf("Comprehensive historical log of decision %d: Detailed rationale spanning multiple distributed sessions with extensive metadata padding: %s", i, strings.Repeat("ABCDEFGHIJ", 20)),
			Confidence:  float64(i) / 250.0,
			LastUpdated: "2026-10-07T00:00:00Z",
		}
		_ = store.SaveKnowledgeNode(ctx, node)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/memory/bundle", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	rawBytes := w.Body.Bytes()
	if len(rawBytes) > config.MaxBundleSizeBytes {
		t.Fatalf("Hard limit violated: bundle raw body size %d bytes > %d limit (50 KB)", len(rawBytes), config.MaxBundleSizeBytes)
	}

	var bundle models.CompactEdgeMemoryBundle
	if err := json.Unmarshal(rawBytes, &bundle); err != nil {
		t.Fatalf("Failed to unmarshal bundle: %v", err)
	}

	if bundle.SizeBytes > config.MaxBundleSizeBytes {
		t.Fatalf("Hard limit violated: bundle.SizeBytes %d > %d", bundle.SizeBytes, config.MaxBundleSizeBytes)
	}
	if bundle.TotalAnchors == 0 {
		t.Errorf("Expected anchors to be preserved after pruning, got 0")
	}

	t.Logf("Strict 50 KB limit verified: packed %d anchors into %d bytes (limit: 51200)", bundle.TotalAnchors, len(rawBytes))
}
