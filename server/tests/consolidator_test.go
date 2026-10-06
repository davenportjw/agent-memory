package tests

import (
	"context"
	"strings"
	"testing"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/memory"
	"mult-agent-madness/server/pkg/models"
	"mult-agent-madness/server/pkg/vertex"
)

func TestOfflineConsolidationEngine(t *testing.T) {
	ctx := context.Background()
	cfg := &config.Config{
		ProjectID:          config.DefaultProjectID,
		Location:           config.DefaultLocation,
		ModelID:            config.ModelGeminiFlash,
		MaxBundleSizeBytes: config.MaxBundleSizeBytes,
	}

	store := memory.NewInMemoryStore()
	vClient, _ := vertex.NewClient(cfg, nil)
	consolidator := memory.NewConsolidator(cfg, vClient, store)

	// Ingest turns covering user preferences, architecture, and contradiction
	turns := []*models.EpisodicTurn{
		{
			ID:            "turn_01",
			SessionID:     "sess_arch",
			UserPrompt:    "Jason prefers Dart for the frontend client and Golang for the Cloud Run microservice.",
			ModelResponse: "Understood. The architecture will align with Flutter Web on Dart and Cloud Run on Go.",
			Route:         models.RouteEdgeLocal,
			EntitiesExtracted: []models.ExtractedEntity{
				{EntityType: "PREFERENCE", EntityValue: "Dart for frontend", Confidence: 0.95},
				{EntityType: "PREFERENCE", EntityValue: "Golang for Cloud Run", Confidence: 0.95},
			},
		},
		{
			ID:            "turn_02",
			SessionID:     "sess_arch",
			UserPrompt:    "Deploy backend on port 8080. Wait, Cloud Run requires listening on PORT env var (usually 8080).",
			ModelResponse: "Acknowledged. We will bind to 0.0.0.0 and inspect os.Getenv('PORT') with a default fallback to 8080.",
			Route:         models.RouteCloudEscalate,
		},
		{
			ID:            "turn_03",
			SessionID:     "sess_arch",
			UserPrompt:    "Always enforce strict PII redaction on device before cloud egress.",
			ModelResponse: "Strict local PII redaction policy registered.",
			Route:         models.RouteEdgeLocal,
		},
	}

	for _, turn := range turns {
		if err := store.SaveEpisodicTurn(ctx, turn); err != nil {
			t.Fatalf("Failed to save turn: %v", err)
		}
	}

	// Run offline consolidation
	resp, err := consolidator.Consolidate(ctx, "sess_arch", false)
	if err != nil {
		t.Fatalf("Consolidation failed: %v", err)
	}

	if resp.ConsolidatedTurns != 3 {
		t.Errorf("Expected 3 consolidated turns, got %d", resp.ConsolidatedTurns)
	}
	if resp.NodesUpdated == 0 {
		t.Errorf("Expected at least 1 knowledge node updated, got 0")
	}

	// Verify turns are now marked consolidated
	unconsolidated, err := store.GetUnconsolidatedTurns(ctx, "sess_arch")
	if err != nil || len(unconsolidated) != 0 {
		t.Fatalf("Expected 0 unconsolidated turns after consolidation, got %d", len(unconsolidated))
	}

	// Verify knowledge nodes in store
	allNodes, err := store.GetAllKnowledgeNodes(ctx)
	if err != nil || len(allNodes) == 0 {
		t.Fatalf("Expected stored knowledge nodes, got %v", allNodes)
	}

	var foundPortArch, foundPref, foundSec bool
	for _, n := range allNodes {
		t.Logf("Consolidated Node: %s [%s] Summary: %s", n.EntityName, n.Category, n.Summary)
		lowerName := strings.ToLower(n.EntityName)
		lowerSummary := strings.ToLower(n.Summary)
		if strings.Contains(lowerName, "port") || strings.Contains(lowerSummary, "port") || n.Category == models.CategorySystemArchitecture {
			foundPortArch = true
		}
		if n.Category == models.CategoryUserPreference {
			foundPref = true
		}
		if n.Category == models.CategorySecurityPolicy {
			foundSec = true
		}
	}

	if !foundPortArch {
		t.Errorf("Expected port/system architecture node to be consolidated, nodes were: %v", allNodes)
	}
	if !foundPref {
		t.Errorf("Expected user preference node to be consolidated")
	}
	if !foundSec {
		t.Errorf("Expected security policy node to be consolidated")
	}
}
