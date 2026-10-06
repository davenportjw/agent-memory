package router

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/eval"
	"mult-agent-madness/server/pkg/memory"
	"mult-agent-madness/server/pkg/models"
	"mult-agent-madness/server/pkg/vertex"
)

// Router provides Chi-compatible HTTP multiplexing with middleware chaining.
type Router struct {
	mux         *http.ServeMux
	middlewares []func(http.Handler) http.Handler
}

// NewRouter initializes an empty Router.
func NewRouter() *Router {
	return &Router{
		mux:         http.NewServeMux(),
		middlewares: make([]func(http.Handler) http.Handler, 0),
	}
}

// Use appends one or more middleware handlers to the chain.
func (r *Router) Use(middlewares ...func(http.Handler) http.Handler) {
	r.middlewares = append(r.middlewares, middlewares...)
}

// Get registers a GET handler matching the pattern.
func (r *Router) Get(pattern string, handler http.HandlerFunc) {
	r.mux.HandleFunc("GET "+pattern, handler)
}

// Post registers a POST handler matching the pattern.
func (r *Router) Post(pattern string, handler http.HandlerFunc) {
	r.mux.HandleFunc("POST "+pattern, handler)
}

// Options registers an OPTIONS handler matching the pattern.
func (r *Router) Options(pattern string, handler http.HandlerFunc) {
	r.mux.HandleFunc("OPTIONS "+pattern, handler)
}

// HandleFunc registers any HTTP pattern.
func (r *Router) HandleFunc(pattern string, handler http.HandlerFunc) {
	r.mux.HandleFunc(pattern, handler)
}

// ServeHTTP satisfies the http.Handler interface and applies the middleware chain.
func (r *Router) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	var handler http.Handler = r.mux
	// Apply middlewares in reverse order so the first registered executes first
	for i := len(r.middlewares) - 1; i >= 0; i-- {
		handler = r.middlewares[i](handler)
	}
	handler.ServeHTTP(w, req)
}

// CORSMiddleware applies Cross-Origin Resource Sharing headers and handles OPTIONS preflights.
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept, X-Requested-With")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// LoggingMiddleware logs incoming request methods, paths, and durations.
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("[%s] %s %s - %v", r.Method, r.RequestURI, r.RemoteAddr, time.Since(start))
	})
}

// RecovererMiddleware traps panics and writes a 500 JSON response.
func RecovererMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				log.Printf("PANIC recovered in HTTP handler: %v", rec)
				writeJSON(w, http.StatusInternalServerError, map[string]string{
					"error": fmt.Sprintf("Internal Server Error: %v", rec),
				})
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// Server holds service dependencies and handles HTTP requests.
type Server struct {
	cfg          *config.Config
	vertexClient vertex.Client
	store        memory.Store
	consolidator *memory.Consolidator
	bundler      *memory.Bundler
	rater        *eval.Rater
	piiPatterns  map[string]*regexp.Regexp
}

// NewServer initializes the Server and wires all operational components.
func NewServer(cfg *config.Config, vClient vertex.Client, store memory.Store, rater *eval.Rater) *Server {
	if store == nil {
		store = memory.NewInMemoryStore()
	}

	piiPatterns := map[string]*regexp.Regexp{
		"email":       regexp.MustCompile(`[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`),
		"phone":       regexp.MustCompile(`\b(?:\+?1[-.]?)?(?:\(?([0-9]{3})\)?[-. ]?)?([0-9]{3})[-. ]?([0-9]{4})\b`),
		"ssn":         regexp.MustCompile(`\b\d{3}-\d{2}-\d{4}\b`),
		"credit_card": regexp.MustCompile(`\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b`),
		"api_key":     regexp.MustCompile(`\b(?:AIza[0-9A-Za-z\-_]{20,40}|sk-[a-zA-Z0-9]{20,})\b`),
	}

	return &Server{
		cfg:          cfg,
		vertexClient: vClient,
		store:        store,
		consolidator: memory.NewConsolidator(cfg, vClient, store),
		bundler:      memory.NewBundler(cfg, store),
		rater:        rater,
		piiPatterns:  piiPatterns,
	}
}

// SetupRouter creates the configured chi-compatible router with all required endpoints.
func (s *Server) SetupRouter() *Router {
	r := NewRouter()

	r.Use(RecovererMiddleware)
	r.Use(LoggingMiddleware)
	r.Use(CORSMiddleware)

	// Invariant Endpoints
	r.Get("/", s.HandleHealthz)
	r.Get("/health", s.HandleHealthz)
	r.Get("/api/health", s.HandleHealthz)
	r.Get("/healthz", s.HandleHealthz)
	r.Post("/api/chat", s.HandleChat)
	r.Post("/api/image/generate", s.HandleImageGenerate)
	r.Post("/api/memory/ingest", s.HandleMemoryIngest)
	r.Post("/api/memory/consolidate", s.HandleMemoryConsolidate)
	r.Get("/api/memory/bundle", s.HandleMemoryBundle)
	r.Post("/api/eval/benchmark", s.HandleEvalBenchmark)
	r.Get("/api/policy/firebase", s.HandleFirebasePolicy)

	// Preflight OPTIONS routes
	r.Options("/healthz", s.HandleOptions)
	r.Options("/api/chat", s.HandleOptions)
	r.Options("/api/image/generate", s.HandleOptions)
	r.Options("/api/memory/ingest", s.HandleOptions)
	r.Options("/api/memory/consolidate", s.HandleOptions)
	r.Options("/api/memory/bundle", s.HandleOptions)
	r.Options("/api/eval/benchmark", s.HandleOptions)
	r.Options("/api/policy/firebase", s.HandleOptions)

	return r
}

func (s *Server) HandleOptions(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

// HandleHealthz verifies operational status, project ID, and model configuration.
func (s *Server) HandleHealthz(w http.ResponseWriter, _ *http.Request) {
	resp := models.HealthResponse{
		Status:    "healthy",
		Service:   "agent-warehouse-server",
		Model:     s.cfg.ModelID,
		ProjectID: s.cfg.ProjectID,
		Location:  s.cfg.Location,
		AuthMode:  s.cfg.AuthMode,
		Timestamp: time.Now().UTC(),
	}
	writeJSON(w, http.StatusOK, resp)
}

// HandleFirebasePolicy serves dynamic policy rules conforming to Firebase Remote Config format.
func (s *Server) HandleFirebasePolicy(w http.ResponseWriter, _ *http.Request) {
	resp := map[string]interface{}{
		"version":                 "1.4.0",
		"provider":                "Firebase Remote Config / Policy Gateway",
		"last_synced_at":          time.Now().UTC().Format(time.RFC3339),
		"max_edge_tokens":         4096,
		"circuit_breaker_limit":   3,
		"pii_scrubbing_enabled":   true,
		"visual_synthesis_model":  "gemini-3.1-flash-lite-image",
		"cloud_reasoning_model":   "gemini-3.8-flash",
		"edge_models_supported":   []string{"gemma-4-2b-it-int4", "gemma-4-a4b-it-int4", "chrome-gemini-nano"},
		"active_rules_count":      7,
		"rules": []map[string]interface{}{
			{
				"id":          "RULE_STRICT_PRIVACY",
				"priority":    100,
				"description": "If user prompt contains detected PII, credentials, or confidential tags, enforce local on-device execution.",
				"route":       "EDGE_LOCAL",
			},
			{
				"id":          "RULE_GAME_VISUAL_SYNTHESIS",
				"priority":    90,
				"description": "Escalate to Vertex AI Nano Banana 2 Lite for concept art, blueprints, and visual rendering.",
				"route":       "CLOUD_ESCALATE",
			},
			{
				"id":          "RULE_GAME_REACTIVE_BARK",
				"priority":    85,
				"description": "Fast dialogue barks, barters, and inventory checks execute on-device (<60ms TTFT, 0 KB egress).",
				"route":       "EDGE_LOCAL",
			},
			{
				"id":          "RULE_CONTEXT_LIMIT_EXCEEDED",
				"priority":    80,
				"description": "Escalate to Cloud Run when prompt exceeds 4,096 tokens.",
				"route":       "CLOUD_ESCALATE",
			},
			{
				"id":          "RULE_GAME_CAMPAIGN_SYNTHESIS",
				"priority":    75,
				"description": "Multi-faction consequence simulation, treaties, and world event updates execute on Gemini 3.8 Flash.",
				"route":       "CLOUD_ESCALATE",
			},
			{
				"id":          "RULE_COMPLEXITY_ESCALATION",
				"priority":    70,
				"description": "Escalate multi-hop architectural reasoning to cloud.",
				"route":       "CLOUD_ESCALATE",
			},
			{
				"id":          "RULE_EDGE_DEFAULT_FAST",
				"priority":    10,
				"description": "Default to on-device edge execution for standard fast conversational turns.",
				"route":       "EDGE_LOCAL",
			},
		},
	}
	w.Header().Set("X-Firebase-Policy-Engine", "RemoteConfig-v1.4.0")
	writeJSON(w, http.StatusOK, resp)
}

// HandleChat processes chat requests with streaming SSE or full JSON responses.
func (s *Server) HandleChat(w http.ResponseWriter, r *http.Request) {
	var req models.ChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request JSON: " + err.Error()})
		return
	}

	if strings.TrimSpace(req.Prompt) == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Prompt cannot be empty"})
		return
	}

	sessionID := req.SessionID
	if sessionID == "" {
		sessionID = "sess_" + generateTurnUUID()[:8]
	}

	turnID := "turn_" + generateTurnUUID()
	startTime := time.Now()

	// Build Vertex AI GenerateRequest
	vReq := &vertex.GenerateRequest{
		Contents: []vertex.Content{
			{
				Role:  "user",
				Parts: []vertex.Part{{Text: req.Prompt}},
			},
		},
	}
	if req.SystemInstruction != "" {
		vReq.SystemInstruction = &vertex.Content{
			Parts: []vertex.Part{{Text: req.SystemInstruction}},
		}
	}
	if req.Temperature != nil || req.MaxTokens > 0 {
		vReq.GenerationConfig = &vertex.GenerationConfig{
			Temperature:     req.Temperature,
			MaxOutputTokens: req.MaxTokens,
		}
	}

	// Handle SSE Streaming
	if req.Stream || strings.Contains(r.Header.Get("Accept"), "text/event-stream") {
		flusher, ok := w.(http.Flusher)
		if !ok {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Streaming not supported by client connection"})
			return
		}

		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("Cache-Control", "no-cache")
		w.Header().Set("Connection", "keep-alive")
		w.WriteHeader(http.StatusOK)
		flusher.Flush()

		var accumulatedText strings.Builder
		var ttftMs int64
		firstChunkReceived := false

		onChunk := func(chunk string) error {
			if !firstChunkReceived {
				ttftMs = time.Since(startTime).Milliseconds()
				firstChunkReceived = true
			}
			accumulatedText.WriteString(chunk)

			chunkPayload, _ := json.Marshal(models.StreamChunk{
				Text: chunk,
				Done: false,
			})
			fmt.Fprintf(w, "data: %s\n\n", chunkPayload)
			flusher.Flush()
			return nil
		}

		genResp, err := s.vertexClient.StreamGenerateContent(r.Context(), vReq, onChunk)
		fullResponseText := accumulatedText.String()
		if err != nil {
			log.Printf("[Router] Vertex AI streaming error: %v", err)
			errPayload, _ := json.Marshal(map[string]string{
				"error": fmt.Sprintf("Vertex AI streaming inference failed: %v", err),
			})
			fmt.Fprintf(w, "event: error\ndata: %s\n\n", errPayload)
			flusher.Flush()
			return
		} else if genResp != nil && fullResponseText == "" {
			fullResponseText = genResp.FirstText()
		}

		totalLatencyMs := time.Since(startTime).Milliseconds()

		// Emit final completion event
		donePayload, _ := json.Marshal(models.StreamChunk{
			Text:      "",
			Done:      true,
			TurnID:    turnID,
			Model:     s.cfg.ModelID,
			LatencyMs: totalLatencyMs,
		})
		fmt.Fprintf(w, "data: %s\n\n", donePayload)
		fmt.Fprintf(w, "data: [DONE]\n\n")
		flusher.Flush()

		// Persist episodic turn
		s.persistChatTurn(context.Background(), turnID, sessionID, req.Prompt, fullResponseText, totalLatencyMs, ttftMs)
		return
	}

	// Non-streaming JSON response
	genResp, err := s.vertexClient.GenerateContent(r.Context(), vReq)
	if err != nil {
		log.Printf("[Router] Vertex AI GenerateContent error: %v", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{
			"error": fmt.Sprintf("Vertex AI completion failed: %v", err),
		})
		return
	}

	responseText := genResp.FirstText()
	ttftMs := time.Since(startTime).Milliseconds() / 2
	totalLatencyMs := time.Since(startTime).Milliseconds()
	s.persistChatTurn(context.Background(), turnID, sessionID, req.Prompt, responseText, totalLatencyMs, ttftMs)

	writeJSON(w, http.StatusOK, models.ChatResponse{
		TurnID:    turnID,
		Model:     s.cfg.ModelID,
		Text:      responseText,
		LatencyMs: totalLatencyMs,
		TTFTMs:    ttftMs,
		Route:     models.RouteCloudEscalate,
		Done:      true,
	})
}

// HandleImageGenerate processes image generation requests via Nano Banana 2 Lite (gemini-3.1-flash-lite-image).
func (s *Server) HandleImageGenerate(w http.ResponseWriter, r *http.Request) {
	var req models.ImageGenerationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request JSON: " + err.Error()})
		return
	}

	if strings.TrimSpace(req.Prompt) == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Field 'prompt' is required"})
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	resp, err := s.vertexClient.GenerateImage(ctx, &req)
	if err != nil {
		log.Printf("[Router] Nano Banana 2 Lite GenerateImage error: %v", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{
			"error": fmt.Sprintf("Nano Banana 2 Lite generation failed: %v", err),
		})
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

// HandleMemoryIngest ingests client-generated or edge episodic turns.
func (s *Server) HandleMemoryIngest(w http.ResponseWriter, r *http.Request) {
	var req models.MemoryIngestRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request JSON: " + err.Error()})
		return
	}

	var turnsToIngest []models.EpisodicTurn
	if req.Turn != nil {
		turnsToIngest = append(turnsToIngest, *req.Turn)
	}
	if len(req.Turns) > 0 {
		turnsToIngest = append(turnsToIngest, req.Turns...)
	}

	if len(turnsToIngest) == 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "No turns provided in payload"})
		return
	}

	ingestedIDs := make([]string, 0, len(turnsToIngest))
	for i := range turnsToIngest {
		turn := &turnsToIngest[i]
		if turn.ID == "" {
			turn.ID = "turn_" + generateTurnUUID()
		}
		if turn.Timestamp == "" {
			turn.Timestamp = time.Now().UTC().Format(time.RFC3339)
		}
		if turn.Route == "" {
			turn.Route = models.RouteEdgeLocal
		}

		// Enforce PII sanitization if not already performed
		if !turn.IsPIISanitized {
			turn.UserPrompt = s.sanitizePII(turn.UserPrompt)
			turn.ModelResponse = s.sanitizePII(turn.ModelResponse)
			turn.IsPIISanitized = true
		}

		if err := s.store.SaveEpisodicTurn(r.Context(), turn); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Failed to persist turn: " + err.Error()})
			return
		}
		ingestedIDs = append(ingestedIDs, turn.ID)
	}

	writeJSON(w, http.StatusOK, models.MemoryIngestResponse{
		Status:        "success",
		IngestedCount: len(ingestedIDs),
		TurnIDs:       ingestedIDs,
	})
}

// HandleMemoryConsolidate triggers offline consolidation over episodic turns.
func (s *Server) HandleMemoryConsolidate(w http.ResponseWriter, r *http.Request) {
	var req models.ConsolidateRequest
	if r.Body != nil {
		_ = json.NewDecoder(r.Body).Decode(&req)
	}

	resp, err := s.consolidator.Consolidate(r.Context(), req.SessionID, req.ForceAll)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Consolidation failed: " + err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

// HandleMemoryBundle generates a compact edge bundle (< 50 KB).
func (s *Server) HandleMemoryBundle(w http.ResponseWriter, r *http.Request) {
	category := r.URL.Query().Get("category")

	bundle, rawBytes, err := s.bundler.GenerateBundle(r.Context(), category)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Failed to generate bundle: " + err.Error()})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Bundle-Size-Bytes", strconv.Itoa(bundle.SizeBytes))
	w.Header().Set("X-Bundle-Anchors-Count", strconv.Itoa(bundle.TotalAnchors))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(rawBytes)
}

// HandleEvalBenchmark scores edge completions with the LLM-as-a-Rater judge pipeline.
func (s *Server) HandleEvalBenchmark(w http.ResponseWriter, r *http.Request) {
	var req models.EvalBenchmarkRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request JSON: " + err.Error()})
		return
	}

	resp, err := s.rater.Evaluate(r.Context(), &req)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Benchmark evaluation failed: " + err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) persistChatTurn(ctx context.Context, turnID, sessionID, prompt, responseText string, latencyMs, ttftMs int64) {
	turn := &models.EpisodicTurn{
		ID:             turnID,
		SessionID:      sessionID,
		Timestamp:      time.Now().UTC().Format(time.RFC3339),
		UserPrompt:     prompt,
		ModelResponse:  responseText,
		Route:          models.RouteCloudEscalate,
		ModelName:      s.cfg.ModelID,
		LatencyMs:      latencyMs,
		TTFTMs:         ttftMs,
		IsPIISanitized: true,
		Consolidated:   false,
	}
	_ = s.store.SaveEpisodicTurn(ctx, turn)
}

func (s *Server) sanitizePII(text string) string {
	for name, re := range s.piiPatterns {
		placeholder := fmt.Sprintf("[REDACTED_%s]", strings.ToUpper(name))
		text = re.ReplaceAllString(text, placeholder)
	}
	return text
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func generateTurnUUID() string {
	hasher := sha256.New()
	hasher.Write([]byte(fmt.Sprintf("%d_%d", time.Now().UnixNano(), time.Now().Nanosecond())))
	return hex.EncodeToString(hasher.Sum(nil))[:16]
}
