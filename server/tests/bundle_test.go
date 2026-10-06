package tests

import (
	"context"
	"fmt"
	"testing"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/memory"
	"mult-agent-madness/server/pkg/models"
)

func TestBundleGenerationAndSizeLimit(t *testing.T) {
	ctx := context.Background()
	cfg := &config.Config{
		MaxBundleSizeBytes: config.MaxBundleSizeBytes, // 51200 bytes
	}
	store := memory.NewInMemoryStore()
	bundler := memory.NewBundler(cfg, store)

	// Populate initial knowledge nodes
	for i := 1; i <= 10; i++ {
		_ = store.SaveKnowledgeNode(ctx, &models.DurableKnowledgeNode{
			ID:         fmt.Sprintf("node_%02d", i),
			EntityName: fmt.Sprintf("Key Anchor %d", i),
			Category:   models.CategorySystemArchitecture,
			Summary:    fmt.Sprintf("Summary of architectural anchor %d for edge deployment", i),
			Confidence: 0.90 + float64(i)*0.005,
		})
	}

	bundle, rawJSON, err := bundler.GenerateBundle(ctx, "")
	if err != nil {
		t.Fatalf("GenerateBundle failed: %v", err)
	}

	if bundle.BundleVersion != 1 {
		t.Errorf("Expected bundle version 1, got %d", bundle.BundleVersion)
	}
	if bundle.TotalAnchors != 10 {
		t.Errorf("Expected 10 anchors, got %d", bundle.TotalAnchors)
	}
	if len(rawJSON) > config.MaxBundleSizeBytes {
		t.Fatalf("Bundle exceeded 50 KB limit: %d bytes > %d", len(rawJSON), config.MaxBundleSizeBytes)
	}
	if bundle.SizeBytes != len(rawJSON) {
		t.Errorf("Bundle SizeBytes %d does not match raw JSON length %d", bundle.SizeBytes, len(rawJSON))
	}
}

func TestBundleStrictPruningUnderExcessiveLoad(t *testing.T) {
	ctx := context.Background()
	cfg := &config.Config{
		MaxBundleSizeBytes: 51200, // 50 KB limit
	}
	store := memory.NewInMemoryStore()
	bundler := memory.NewBundler(cfg, store)

	// Insert 200 large knowledge nodes that would easily exceed 50 KB
	for i := 1; i <= 200; i++ {
		_ = store.SaveKnowledgeNode(ctx, &models.DurableKnowledgeNode{
			ID:         fmt.Sprintf("large_node_%03d", i),
			EntityName: fmt.Sprintf("Entity Long Name %d with Extended Metadata Context", i),
			Category:   models.CategoryRoadmapDecision,
			Summary:    fmt.Sprintf("Extended comprehensive summary for node %d describing complex multi-turn rationale across distributed sessions with high granularity. Padding: %s", i, "01234567890123456789012345678901234567890123456789"),
			Confidence: float64(i) / 200.0,
		})
	}

	bundle, rawJSON, err := bundler.GenerateBundle(ctx, "")
	if err != nil {
		t.Fatalf("GenerateBundle failed under load: %v", err)
	}

	if len(rawJSON) > config.MaxBundleSizeBytes {
		t.Fatalf("Bundle violated 50 KB limit: %d bytes > %d", len(rawJSON), config.MaxBundleSizeBytes)
	}
	if bundle.SizeBytes != len(rawJSON) {
		t.Errorf("Bundle SizeBytes %d does not match raw JSON length %d", bundle.SizeBytes, len(rawJSON))
	}
	if bundle.TotalAnchors == 0 {
		t.Errorf("Expected some anchors to survive pruning, got 0")
	}

	t.Logf("Successfully packed %d anchors into %d bytes (limit: 51200)", bundle.TotalAnchors, bundle.SizeBytes)
}
