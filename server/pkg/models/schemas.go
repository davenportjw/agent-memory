package models

import "time"

// Route constants matching shared/routing_policy.json
const (
	RouteEdgeLocal     = "EDGE_LOCAL"
	RouteEdgeFallback  = "EDGE_FALLBACK"
	RouteCloudEscalate = "CLOUD_ESCALATE"
)

// Durable knowledge node categories matching shared/memory_schema.json
const (
	CategoryUserPreference     = "USER_PREFERENCE"
	CategorySystemArchitecture = "SYSTEM_ARCHITECTURE"
	CategoryRoadmapDecision    = "ROADMAP_DECISION"
	CategorySecurityPolicy     = "SECURITY_POLICY"
	CategoryFactionState       = "FACTION_STATE"
	CategoryNpcRelation        = "NPC_RELATION"
	CategoryWorldEvent         = "WORLD_EVENT"
	CategoryLoreCanon          = "LORE_CANON"
)

// ExtractedEntity defines an entity pulled from episodic turns.
type ExtractedEntity struct {
	EntityType  string  `json:"entity_type"`
	EntityValue string  `json:"entity_value"`
	Confidence  float64 `json:"confidence,omitempty"`
}

// EpisodicTurn mirrors the definition in shared/memory_schema.json.
type EpisodicTurn struct {
	ID                string            `json:"id"`
	SessionID         string            `json:"session_id"`
	Timestamp         string            `json:"timestamp"` // RFC3339
	UserPrompt        string            `json:"user_prompt"`
	ModelResponse     string            `json:"model_response"`
	Route             string            `json:"route"` // EDGE_LOCAL, EDGE_FALLBACK, CLOUD_ESCALATE
	ModelName         string            `json:"model_name"`
	LatencyMs         int64             `json:"latency_ms"`
	TTFTMs            int64             `json:"ttft_ms"`
	IsPIISanitized    bool              `json:"is_pii_sanitized"`
	EntitiesExtracted []ExtractedEntity `json:"entities_extracted"`
	Consolidated      bool              `json:"consolidated,omitempty"`
}

// NodeRelation describes directed edges in the durable knowledge graph.
type NodeRelation struct {
	Predicate    string `json:"predicate"`
	TargetNodeID string `json:"target_node_id"`
}

// DurableKnowledgeNode mirrors the definition in shared/memory_schema.json.
type DurableKnowledgeNode struct {
	ID                     string         `json:"id"`
	EntityName             string         `json:"entity_name"`
	Category               string         `json:"category"` // USER_PREFERENCE, SYSTEM_ARCHITECTURE, ROADMAP_DECISION, SECURITY_POLICY
	Summary                string         `json:"summary"`
	Confidence             float64        `json:"confidence"` // 0.0 to 1.0
	Relations              []NodeRelation `json:"relations,omitempty"`
	SourceEpisodeIDs       []string       `json:"source_episode_ids"`
	ResolvedContradictions []string       `json:"resolved_contradictions,omitempty"`
	LastUpdated            string         `json:"last_updated"` // RFC3339
}

// MemoryAnchor defines an anchor item in the compact edge bundle.
type MemoryAnchor struct {
	AnchorID         string `json:"anchor_id"`
	Key              string `json:"key"`
	Category         string `json:"category,omitempty"`
	DistilledContext string `json:"distilled_context"`
}

// CompactEdgeMemoryBundle mirrors the definition in shared/memory_schema.json.
// Hard constraint: size_bytes <= 51200 (< 50 KB).
type CompactEdgeMemoryBundle struct {
	BundleVersion int            `json:"bundle_version"`
	CreatedAt     string         `json:"created_at"` // RFC3339
	TotalAnchors  int            `json:"total_anchors"`
	SizeBytes     int            `json:"size_bytes"`
	Anchors       []MemoryAnchor `json:"anchors"`
}

// ChatRequest payload for /api/chat.
type ChatRequest struct {
	Prompt            string   `json:"prompt"`
	SessionID         string   `json:"session_id,omitempty"`
	SystemInstruction string   `json:"system_instruction,omitempty"`
	Temperature       *float64 `json:"temperature,omitempty"`
	MaxTokens         int      `json:"max_tokens,omitempty"`
	Stream            bool     `json:"stream"`
	Route             string   `json:"route,omitempty"`
}

// ChatResponse payload for non-streaming /api/chat.
type ChatResponse struct {
	TurnID    string `json:"turn_id"`
	Model     string `json:"model"`
	Text      string `json:"text"`
	LatencyMs int64  `json:"latency_ms"`
	TTFTMs    int64  `json:"ttft_ms"`
	Route     string `json:"route"`
	Done      bool   `json:"done"`
}

// StreamChunk emitted over SSE for streaming /api/chat.
type StreamChunk struct {
	Text      string `json:"text"`
	Done      bool   `json:"done"`
	TurnID    string `json:"turn_id,omitempty"`
	Model     string `json:"model,omitempty"`
	LatencyMs int64  `json:"latency_ms,omitempty"`
}

// MemoryIngestRequest payload for /api/memory/ingest.
type MemoryIngestRequest struct {
	Turns []EpisodicTurn `json:"turns,omitempty"`
	Turn  *EpisodicTurn  `json:"turn,omitempty"`
}

// MemoryIngestResponse payload for /api/memory/ingest.
type MemoryIngestResponse struct {
	Status        string   `json:"status"`
	IngestedCount int      `json:"ingested_count"`
	TurnIDs       []string `json:"turn_ids"`
}

// ConsolidateRequest payload for /api/memory/consolidate.
type ConsolidateRequest struct {
	SessionID string `json:"session_id,omitempty"`
	ForceAll  bool   `json:"force_all,omitempty"`
}

// ConsolidateResponse payload for /api/memory/consolidate.
type ConsolidateResponse struct {
	Status            string                 `json:"status"`
	ConsolidatedTurns int                    `json:"consolidated_turns"`
	NodesUpdated      int                    `json:"nodes_updated"`
	Nodes             []DurableKnowledgeNode `json:"nodes"`
}

// RubricScore holds evaluation for an individual rubric criterion.
type RubricScore struct {
	Name     string  `json:"name"`
	Score    float64 `json:"score"` // 1.0 to 5.0
	Weight   float64 `json:"weight"`
	Feedback string  `json:"feedback"`
}

// EvalBenchmarkRequest payload for /api/eval/benchmark.
type EvalBenchmarkRequest struct {
	BenchmarkID    string                 `json:"benchmark_id,omitempty"`
	Prompt         string                 `json:"prompt,omitempty"`
	EdgeCompletion string                 `json:"edge_completion"`
	GoldenCriteria map[string]interface{} `json:"golden_criteria,omitempty"`
	LatencyMs      int64                  `json:"latency_ms,omitempty"`
	TTFTMs         int64                  `json:"ttft_ms,omitempty"`
}

// EvalBenchmarkResponse payload for /api/eval/benchmark.
type EvalBenchmarkResponse struct {
	BenchmarkID  string                 `json:"benchmark_id"`
	JudgeModel   string                 `json:"judge_model"` // gemini-3.8-flash
	OverallScore float64                `json:"overall_score"`
	Passed       bool                   `json:"passed"`
	RubricScores map[string]RubricScore `json:"rubric_scores"`
	Reasoning    string                 `json:"reasoning"`
	EvaluatedAt  string                 `json:"evaluated_at"`
}

// HealthResponse payload for /healthz.
type HealthResponse struct {
	Status    string    `json:"status"`
	Service   string    `json:"service"`
	Model     string    `json:"model"`
	ProjectID string    `json:"project_id"`
	Location  string    `json:"location"`
	AuthMode  string    `json:"auth_mode"`
	Timestamp time.Time `json:"timestamp"`
}

// ImageGenerationRequest payload for /api/image/generate.
type ImageGenerationRequest struct {
	Prompt         string   `json:"prompt"`
	AspectRatio    string   `json:"aspect_ratio,omitempty"` // 1:1, 16:9, 4:3
	SampleCount    int      `json:"sample_count,omitempty"`
	ContextAnchors []string `json:"context_anchors,omitempty"`
	SessionID      string   `json:"session_id,omitempty"`
}

// ImageGenerationResponse payload from /api/image/generate.
type ImageGenerationResponse struct {
	ImageBase64 string `json:"image_base64"`
	MimeType    string `json:"mime_type"`
	ModelID     string `json:"model_id"` // gemini-3.1-flash-lite-image (Nano Banana 2 Lite)
	Prompt      string `json:"prompt"`
	LatencyMs   int64  `json:"latency_ms"`
	EgressBytes int    `json:"egress_bytes"`
	GeneratedAt string `json:"generated_at"`
}
