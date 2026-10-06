package memory

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/models"
)

// Bundler packages durable knowledge nodes into compact edge-deployable memory bundles.
type Bundler struct {
	cfg   *config.Config
	store Store
}

// NewBundler constructs a new edge memory bundler.
func NewBundler(cfg *config.Config, store Store) *Bundler {
	return &Bundler{
		cfg:   cfg,
		store: store,
	}
}

// GenerateBundle retrieves active durable knowledge nodes and packages them into
// a CompactEdgeMemoryBundle strictly bounded under 50 KB (51,200 bytes).
func (b *Bundler) GenerateBundle(ctx context.Context, categoryFilter string) (*models.CompactEdgeMemoryBundle, []byte, error) {
	var nodes []*models.DurableKnowledgeNode
	var err error

	if categoryFilter != "" {
		nodes, err = b.store.GetKnowledgeNodesByCategory(ctx, categoryFilter)
	} else {
		nodes, err = b.store.GetAllKnowledgeNodes(ctx)
	}
	if err != nil {
		return nil, nil, fmt.Errorf("failed to fetch knowledge nodes: %w", err)
	}

	// Sort nodes by confidence descending so the highest-signal memories are preserved
	sort.Slice(nodes, func(i, j int) bool {
		if nodes[i].Confidence != nodes[j].Confidence {
			return nodes[i].Confidence > nodes[j].Confidence
		}
		return nodes[i].LastUpdated > nodes[j].LastUpdated
	})

	maxBytes := b.cfg.MaxBundleSizeBytes
	if maxBytes <= 0 || maxBytes > config.MaxBundleSizeBytes {
		maxBytes = config.MaxBundleSizeBytes
	}

	anchors := make([]models.MemoryAnchor, 0, len(nodes))
	for _, n := range nodes {
		contextText := n.Summary
		if len(n.ResolvedContradictions) > 0 {
			contextText = fmt.Sprintf("%s [Resolved: %s]", contextText, strings.Join(n.ResolvedContradictions, "; "))
		}

		anchors = append(anchors, models.MemoryAnchor{
			AnchorID:         n.ID,
			Key:              n.EntityName,
			Category:         n.Category,
			DistilledContext: contextText,
		})
	}

	bundle := &models.CompactEdgeMemoryBundle{
		BundleVersion: 1,
		CreatedAt:     time.Now().UTC().Format(time.RFC3339),
		TotalAnchors:  len(anchors),
		SizeBytes:     0,
		Anchors:       anchors,
	}

	// Serialize and enforce hard size limit (< 50 KB)
	jsonBytes, err := json.Marshal(bundle)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to marshal initial bundle: %w", err)
	}

	// If initial payload exceeds budget, prune anchors or distill context
	for len(jsonBytes) > maxBytes && len(bundle.Anchors) > 0 {
		// Drop lowest-confidence anchor (from the end)
		bundle.Anchors = bundle.Anchors[:len(bundle.Anchors)-1]
		bundle.TotalAnchors = len(bundle.Anchors)

		// Recalculate
		jsonBytes, err = json.Marshal(bundle)
		if err != nil {
			return nil, nil, fmt.Errorf("failed to marshal pruned bundle: %w", err)
		}
	}

	// If single anchor exceeds maxBytes, truncate its distilled context
	if len(bundle.Anchors) == 1 && len(jsonBytes) > maxBytes {
		allowedContextLen := maxBytes - 250 // budget for JSON envelope
		if allowedContextLen > 0 && len(bundle.Anchors[0].DistilledContext) > allowedContextLen {
			bundle.Anchors[0].DistilledContext = bundle.Anchors[0].DistilledContext[:allowedContextLen] + "..."
			jsonBytes, _ = json.Marshal(bundle)
		}
	}

	// Finalize exact size_bytes field matching serialized payload length
	bundle.SizeBytes = len(jsonBytes)
	finalJSON, err := json.Marshal(bundle)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to serialize final bundle: %w", err)
	}
	bundle.SizeBytes = len(finalJSON)

	return bundle, finalJSON, nil
}
