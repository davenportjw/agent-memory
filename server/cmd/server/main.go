package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/eval"
	"mult-agent-madness/server/pkg/memory"
	"mult-agent-madness/server/pkg/router"
	"mult-agent-madness/server/pkg/vertex"
)

func main() {
	log.Println("Initializing Distributed AI Cloud Run Microservice...")

	// 1. Load configuration with strict invariant validation
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Fatal config error: %v", err)
	}

	log.Printf("[Config] Project: %s, Region: %s, Model: %s, Port: %s, Auth: %s",
		cfg.ProjectID, cfg.Location, cfg.ModelID, cfg.Port, cfg.AuthMode)

	// 2. Initialize Vertex AI Gemini 3.8 Flash Client
	httpClient := &http.Client{Timeout: 90 * time.Second}
	vClient, err := vertex.NewClient(cfg, httpClient)
	if err != nil {
		log.Fatalf("Failed to initialize Vertex AI client: %v", err)
	}

	// 3. Initialize Memory Store (Firestore or durable In-Memory)
	tokenSource := vertex.NewADCTokenSource(httpClient)
	store := memory.NewStore(cfg, tokenSource)
	defer store.Close()

	// 4. Initialize LLM-as-a-Rater Judge Pipeline
	rater, err := eval.NewRater(cfg, vClient, "")
	if err != nil {
		log.Printf("Warning: evaluator initialized without benchmark suite: %v", err)
	}

	// 5. Construct Service & Router
	srv := router.NewServer(cfg, vClient, store, rater)
	r := srv.SetupRouter()

	addr := fmt.Sprintf("0.0.0.0:%s", cfg.Port)
	httpServer := &http.Server{
		Addr:         addr,
		Handler:      r,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 90 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// 6. Graceful Shutdown Channel
	stopChan := make(chan os.Signal, 1)
	signal.Notify(stopChan, os.Interrupt, syscall.SIGTERM, syscall.SIGINT)

	// 7. Launch HTTP Server asynchronously
	go func() {
		log.Printf("[Server] Listening on http://%s (Cloud Run ready)", addr)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("Server ListenAndServe error: %v", err)
		}
	}()

	// Wait for shutdown signal
	sig := <-stopChan
	log.Printf("[Server] Received shutdown signal: %v. Initiating graceful drain...", sig)

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("[Server] Error during graceful shutdown: %v", err)
	} else {
		log.Println("[Server] Graceful shutdown completed successfully.")
	}
}
