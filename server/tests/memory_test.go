package tests

import (
	"context"
	"fmt"
	"sync"
	"testing"

	"mult-agent-madness/server/pkg/memory"
	"mult-agent-madness/server/pkg/models"
)

func TestInMemoryStoreTurnOperations(t *testing.T) {
	ctx := context.Background()
	store := memory.NewInMemoryStore()

	// 1. Save turns across multiple sessions
	for i := 1; i <= 5; i++ {
		turn := &models.EpisodicTurn{
			ID:             fmt.Sprintf("turn_%02d", i),
			SessionID:      fmt.Sprintf("sess_%d", i%2),
			UserPrompt:     fmt.Sprintf("Prompt %d", i),
			ModelResponse:  fmt.Sprintf("Response %d", i),
			Route:          models.RouteEdgeLocal,
			Consolidated:   false,
			IsPIISanitized: true,
		}
		if err := store.SaveEpisodicTurn(ctx, turn); err != nil {
			t.Fatalf("Failed to save turn %d: %v", i, err)
		}
	}

	// 2. Fetch turn by ID
	t1, err := store.GetEpisodicTurn(ctx, "turn_01")
	if err != nil {
		t.Fatalf("Failed to get turn_01: %v", err)
	}
	if t1.UserPrompt != "Prompt 1" {
		t.Errorf("Unexpected prompt: %s", t1.UserPrompt)
	}

	// 3. Fetch unconsolidated turns
	unconsolidated, err := store.GetUnconsolidatedTurns(ctx, "")
	if err != nil {
		t.Fatalf("Failed to get unconsolidated turns: %v", err)
	}
	if len(unconsolidated) != 5 {
		t.Fatalf("Expected 5 unconsolidated turns, got %d", len(unconsolidated))
	}

	// 4. Mark turns consolidated
	if err := store.MarkTurnsConsolidated(ctx, []string{"turn_01", "turn_02"}); err != nil {
		t.Fatalf("Failed to mark consolidated: %v", err)
	}

	remaining, err := store.GetUnconsolidatedTurns(ctx, "")
	if err != nil || len(remaining) != 3 {
		t.Fatalf("Expected 3 remaining unconsolidated turns, got %d", len(remaining))
	}
}

func TestKnowledgeNodePersistence(t *testing.T) {
	ctx := context.Background()
	store := memory.NewInMemoryStore()

	node1 := &models.DurableKnowledgeNode{
		ID:         "node_arch_01",
		EntityName: "Cloud Run Topology",
		Category:   models.CategorySystemArchitecture,
		Summary:    "Microservice runs on Cloud Run us-central1",
		Confidence: 0.95,
	}
	node2 := &models.DurableKnowledgeNode{
		ID:         "node_pref_01",
		EntityName: "Theme Preference",
		Category:   models.CategoryUserPreference,
		Summary:    "User prefers sepia academic styling",
		Confidence: 0.90,
	}

	if err := store.SaveKnowledgeNode(ctx, node1); err != nil {
		t.Fatalf("Failed to save node1: %v", err)
	}
	if err := store.SaveKnowledgeNode(ctx, node2); err != nil {
		t.Fatalf("Failed to save node2: %v", err)
	}

	allNodes, err := store.GetAllKnowledgeNodes(ctx)
	if err != nil || len(allNodes) != 2 {
		t.Fatalf("Expected 2 knowledge nodes, got %d", len(allNodes))
	}

	prefNodes, err := store.GetKnowledgeNodesByCategory(ctx, models.CategoryUserPreference)
	if err != nil || len(prefNodes) != 1 {
		t.Fatalf("Expected 1 preference node, got %d", len(prefNodes))
	}
	if prefNodes[0].EntityName != "Theme Preference" {
		t.Errorf("Unexpected entity name: %s", prefNodes[0].EntityName)
	}
}

func TestStoreConcurrency(t *testing.T) {
	ctx := context.Background()
	store := memory.NewInMemoryStore()

	var wg sync.WaitGroup
	workers := 20
	turnsPerWorker := 10

	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for i := 0; i < turnsPerWorker; i++ {
				turnID := fmt.Sprintf("turn_w%d_i%d", workerID, i)
				_ = store.SaveEpisodicTurn(ctx, &models.EpisodicTurn{
					ID:            turnID,
					SessionID:     fmt.Sprintf("sess_w%d", workerID),
					UserPrompt:    "Concurrent prompt",
					ModelResponse: "Concurrent response",
					Route:         models.RouteEdgeLocal,
				})
			}
		}(w)
	}

	wg.Wait()

	turns, err := store.GetUnconsolidatedTurns(ctx, "")
	if err != nil {
		t.Fatalf("Failed to fetch turns after concurrent write: %v", err)
	}
	expected := workers * turnsPerWorker
	if len(turns) != expected {
		t.Fatalf("Expected %d turns, got %d", expected, len(turns))
	}
}
