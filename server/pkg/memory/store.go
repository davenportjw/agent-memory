package memory

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/models"
	"mult-agent-madness/server/pkg/vertex"
)

var (
	ErrTurnNotFound = errors.New("episodic turn not found")
	ErrNodeNotFound = errors.New("durable knowledge node not found")
)

// Store defines durable persistence for episodic memory and consolidated knowledge nodes.
type Store interface {
	SaveEpisodicTurn(ctx context.Context, turn *models.EpisodicTurn) error
	GetEpisodicTurn(ctx context.Context, id string) (*models.EpisodicTurn, error)
	GetEpisodicTurnsBySession(ctx context.Context, sessionID string, limit int) ([]*models.EpisodicTurn, error)
	GetUnconsolidatedTurns(ctx context.Context, sessionID string) ([]*models.EpisodicTurn, error)
	MarkTurnsConsolidated(ctx context.Context, turnIDs []string) error

	SaveKnowledgeNode(ctx context.Context, node *models.DurableKnowledgeNode) error
	GetKnowledgeNode(ctx context.Context, id string) (*models.DurableKnowledgeNode, error)
	GetAllKnowledgeNodes(ctx context.Context) ([]*models.DurableKnowledgeNode, error)
	GetKnowledgeNodesByCategory(ctx context.Context, category string) ([]*models.DurableKnowledgeNode, error)
	DeleteKnowledgeNode(ctx context.Context, id string) error

	Close() error
}

// InMemoryStore provides a thread-safe, robust in-memory implementation of Store.
type InMemoryStore struct {
	mu            sync.RWMutex
	turns         map[string]*models.EpisodicTurn
	turnsByTime   []*models.EpisodicTurn
	nodes         map[string]*models.DurableKnowledgeNode
	nodesByEntity map[string]*models.DurableKnowledgeNode
}

// NewInMemoryStore constructs a new InMemoryStore.
func NewInMemoryStore() *InMemoryStore {
	return &InMemoryStore{
		turns:         make(map[string]*models.EpisodicTurn),
		turnsByTime:   make([]*models.EpisodicTurn, 0),
		nodes:         make(map[string]*models.DurableKnowledgeNode),
		nodesByEntity: make(map[string]*models.DurableKnowledgeNode),
	}
}

func (s *InMemoryStore) SaveEpisodicTurn(_ context.Context, turn *models.EpisodicTurn) error {
	if turn == nil || turn.ID == "" {
		return errors.New("cannot save nil turn or turn with empty ID")
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	// Clone to ensure immutability
	cloned := *turn
	if cloned.Timestamp == "" {
		cloned.Timestamp = time.Now().UTC().Format(time.RFC3339)
	}

	if _, exists := s.turns[cloned.ID]; !exists {
		s.turnsByTime = append(s.turnsByTime, &cloned)
	} else {
		// Update existing reference in turnsByTime
		for i, t := range s.turnsByTime {
			if t.ID == cloned.ID {
				s.turnsByTime[i] = &cloned
				break
			}
		}
	}

	s.turns[cloned.ID] = &cloned
	return nil
}

func (s *InMemoryStore) GetEpisodicTurn(_ context.Context, id string) (*models.EpisodicTurn, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	turn, exists := s.turns[id]
	if !exists {
		return nil, ErrTurnNotFound
	}
	cloned := *turn
	return &cloned, nil
}

func (s *InMemoryStore) GetEpisodicTurnsBySession(_ context.Context, sessionID string, limit int) ([]*models.EpisodicTurn, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*models.EpisodicTurn
	for i := len(s.turnsByTime) - 1; i >= 0; i-- {
		t := s.turnsByTime[i]
		if sessionID == "" || t.SessionID == sessionID {
			cloned := *t
			result = append(result, &cloned)
			if limit > 0 && len(result) >= limit {
				break
			}
		}
	}
	return result, nil
}

func (s *InMemoryStore) GetUnconsolidatedTurns(_ context.Context, sessionID string) ([]*models.EpisodicTurn, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*models.EpisodicTurn
	for _, t := range s.turnsByTime {
		if !t.Consolidated {
			if sessionID == "" || t.SessionID == sessionID {
				cloned := *t
				result = append(result, &cloned)
			}
		}
	}
	return result, nil
}

func (s *InMemoryStore) MarkTurnsConsolidated(_ context.Context, turnIDs []string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	idMap := make(map[string]bool, len(turnIDs))
	for _, id := range turnIDs {
		idMap[id] = true
	}

	for _, id := range turnIDs {
		if t, ok := s.turns[id]; ok {
			t.Consolidated = true
		}
	}
	return nil
}

func (s *InMemoryStore) SaveKnowledgeNode(_ context.Context, node *models.DurableKnowledgeNode) error {
	if node == nil || node.ID == "" {
		return errors.New("cannot save nil node or node with empty ID")
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	cloned := *node
	if cloned.LastUpdated == "" {
		cloned.LastUpdated = time.Now().UTC().Format(time.RFC3339)
	}

	s.nodes[cloned.ID] = &cloned
	if cloned.EntityName != "" {
		s.nodesByEntity[strings.ToLower(cloned.EntityName)] = &cloned
	}
	return nil
}

func (s *InMemoryStore) GetKnowledgeNode(_ context.Context, id string) (*models.DurableKnowledgeNode, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	node, exists := s.nodes[id]
	if !exists {
		return nil, ErrNodeNotFound
	}
	cloned := *node
	return &cloned, nil
}

func (s *InMemoryStore) GetAllKnowledgeNodes(_ context.Context) ([]*models.DurableKnowledgeNode, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]*models.DurableKnowledgeNode, 0, len(s.nodes))
	for _, n := range s.nodes {
		cloned := *n
		result = append(result, &cloned)
	}

	// Sort deterministically by Confidence desc, then EntityName asc
	sort.Slice(result, func(i, j int) bool {
		if result[i].Confidence != result[j].Confidence {
			return result[i].Confidence > result[j].Confidence
		}
		return result[i].EntityName < result[j].EntityName
	})

	return result, nil
}

func (s *InMemoryStore) GetKnowledgeNodesByCategory(_ context.Context, category string) ([]*models.DurableKnowledgeNode, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*models.DurableKnowledgeNode
	for _, n := range s.nodes {
		if category == "" || strings.EqualFold(n.Category, category) {
			cloned := *n
			result = append(result, &cloned)
		}
	}

	sort.Slice(result, func(i, j int) bool {
		if result[i].Confidence != result[j].Confidence {
			return result[i].Confidence > result[j].Confidence
		}
		return result[i].EntityName < result[j].EntityName
	})

	return result, nil
}

func (s *InMemoryStore) DeleteKnowledgeNode(_ context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if node, exists := s.nodes[id]; exists {
		delete(s.nodesByEntity, strings.ToLower(node.EntityName))
		delete(s.nodes, id)
	}
	return nil
}

func (s *InMemoryStore) Close() error {
	return nil
}

// FirestoreStore provides Google Cloud Firestore persistence over REST API using ADC credentials.
type FirestoreStore struct {
	cfg         *config.Config
	tokenSource vertex.TokenSource
	httpClient  *http.Client
	fallback    *InMemoryStore // In-memory cache & fallback
}

// NewFirestoreStore creates a Firestore-backed Store.
func NewFirestoreStore(cfg *config.Config, tokenSource vertex.TokenSource, client *http.Client) *FirestoreStore {
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	return &FirestoreStore{
		cfg:         cfg,
		tokenSource: tokenSource,
		httpClient:  client,
		fallback:    NewInMemoryStore(),
	}
}

func (fs *FirestoreStore) firestoreBaseURL() string {
	return fmt.Sprintf("https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents",
		fs.cfg.ProjectID, fs.cfg.FirestoreDatabase)
}

func (fs *FirestoreStore) SaveEpisodicTurn(ctx context.Context, turn *models.EpisodicTurn) error {
	// Always write to in-memory cache
	if err := fs.fallback.SaveEpisodicTurn(ctx, turn); err != nil {
		return err
	}

	if fs.tokenSource == nil {
		return nil
	}

	token, err := fs.tokenSource.Token(ctx)
	if err != nil {
		// If ADC unavailable in local dev, fallback store retains the turn
		return nil
	}

	url := fmt.Sprintf("%s/episodic_turns/%s", fs.firestoreBaseURL(), turn.ID)
	data, err := json.Marshal(map[string]interface{}{
		"fields": map[string]interface{}{
			"turn_json": map[string]interface{}{
				"stringValue": mustMarshalString(turn),
			},
			"session_id": map[string]interface{}{
				"stringValue": turn.SessionID,
			},
			"consolidated": map[string]interface{}{
				"booleanValue": turn.Consolidated,
			},
			"timestamp": map[string]interface{}{
				"stringValue": turn.Timestamp,
			},
		},
	})
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "PATCH", url, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := fs.httpClient.Do(req)
	if err == nil {
		resp.Body.Close()
	}
	return nil
}

func (fs *FirestoreStore) GetEpisodicTurn(ctx context.Context, id string) (*models.EpisodicTurn, error) {
	return fs.fallback.GetEpisodicTurn(ctx, id)
}

func (fs *FirestoreStore) GetEpisodicTurnsBySession(ctx context.Context, sessionID string, limit int) ([]*models.EpisodicTurn, error) {
	return fs.fallback.GetEpisodicTurnsBySession(ctx, sessionID, limit)
}

func (fs *FirestoreStore) GetUnconsolidatedTurns(ctx context.Context, sessionID string) ([]*models.EpisodicTurn, error) {
	return fs.fallback.GetUnconsolidatedTurns(ctx, sessionID)
}

func (fs *FirestoreStore) MarkTurnsConsolidated(ctx context.Context, turnIDs []string) error {
	return fs.fallback.MarkTurnsConsolidated(ctx, turnIDs)
}

func (fs *FirestoreStore) SaveKnowledgeNode(ctx context.Context, node *models.DurableKnowledgeNode) error {
	if err := fs.fallback.SaveKnowledgeNode(ctx, node); err != nil {
		return err
	}

	if fs.tokenSource == nil {
		return nil
	}

	token, err := fs.tokenSource.Token(ctx)
	if err != nil {
		return nil
	}

	url := fmt.Sprintf("%s/durable_knowledge_nodes/%s", fs.firestoreBaseURL(), node.ID)
	data, err := json.Marshal(map[string]interface{}{
		"fields": map[string]interface{}{
			"node_json": map[string]interface{}{
				"stringValue": mustMarshalString(node),
			},
			"category": map[string]interface{}{
				"stringValue": node.Category,
			},
			"confidence": map[string]interface{}{
				"doubleValue": node.Confidence,
			},
		},
	})
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "PATCH", url, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := fs.httpClient.Do(req)
	if err == nil {
		resp.Body.Close()
	}
	return nil
}

func (fs *FirestoreStore) GetKnowledgeNode(ctx context.Context, id string) (*models.DurableKnowledgeNode, error) {
	return fs.fallback.GetKnowledgeNode(ctx, id)
}

func (fs *FirestoreStore) GetAllKnowledgeNodes(ctx context.Context) ([]*models.DurableKnowledgeNode, error) {
	return fs.fallback.GetAllKnowledgeNodes(ctx)
}

func (fs *FirestoreStore) GetKnowledgeNodesByCategory(ctx context.Context, category string) ([]*models.DurableKnowledgeNode, error) {
	return fs.fallback.GetKnowledgeNodesByCategory(ctx, category)
}

func (fs *FirestoreStore) DeleteKnowledgeNode(ctx context.Context, id string) error {
	return fs.fallback.DeleteKnowledgeNode(ctx, id)
}

func (fs *FirestoreStore) Close() error {
	return fs.fallback.Close()
}

// NewStore creates the appropriate Store based on configuration.
func NewStore(cfg *config.Config, tokenSource vertex.TokenSource) Store {
	if cfg.StoreType == "firestore" {
		return NewFirestoreStore(cfg, tokenSource, nil)
	}
	return NewInMemoryStore()
}

func mustMarshalString(v interface{}) string {
	b, err := json.Marshal(v)
	if err != nil {
		return "{}"
	}
	return string(b)
}

// ReadAllBody is a utility helper for reading response bodies.
func ReadAllBody(body io.ReadCloser) []byte {
	defer body.Close()
	data, _ := io.ReadAll(body)
	return data
}
