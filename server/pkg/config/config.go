package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

const (
	// DefaultProjectID is the fallback GCP project if not configured in environment.
	DefaultProjectID = "davenport-boutique"

	// DefaultLocation is the primary GCP location for Vertex AI Gemini 3.8 models.
	DefaultLocation = "global"

	// ModelGeminiFlash is the exclusive model allowed by architecture invariants.
	// Invariant: Never use gemini-3.8-pro under any circumstances!
	ModelGeminiFlash = "gemini-3.8-flash"

	// ModelNanoBanana2Lite is Google's ultra-fast native image generation model (gemini-3.1-flash-lite-image).
	ModelNanoBanana2Lite = "gemini-3.1-flash-lite-image"

	// ForbiddenModelPro is explicitly forbidden by architecture rules.
	ForbiddenModelPro = "gemini-3.8-pro"

	// MaxBundleSizeBytes defines the edge memory bundle hard limit (< 50 KB).
	MaxBundleSizeBytes = 51200 // 50 * 1024 bytes

	// EdgeMaxContextTokens defines the Gemma 4 edge context capacity.
	EdgeMaxContextTokens = 4096

	// CloudMaxContextTokens defines the Gemini 3.8 Flash context capacity.
	CloudMaxContextTokens = 1048576
)

// Config holds runtime configuration for the Cloud Run microservice.
type Config struct {
	ProjectID          string
	Location           string
	ModelID            string
	Port               string
	AuthMode           string
	MaxBundleSizeBytes int
	StoreType          string // "memory" or "firestore"
	FirestoreDatabase  string
	VertexEndpoint     string
}

// loadEnv reads key=value pairs from .env files if present, without overwriting existing environment variables.
func loadEnv(files ...string) {
	for _, f := range files {
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				k := strings.TrimSpace(parts[0])
				v := strings.TrimSpace(parts[1])
				if len(v) >= 2 && ((v[0] == '"' && v[len(v)-1] == '"') || (v[0] == '\'' && v[len(v)-1] == '\'')) {
					v = v[1 : len(v)-1]
				}
				if os.Getenv(k) == "" {
					_ = os.Setenv(k, v)
				}
			}
		}
	}
}

// Load reads configuration from environment variables and applies invariant defaults.
func Load() (*Config, error) {
	loadEnv(".env", "../.env", "../../.env")

	projectID := os.Getenv("GCP_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("PROJECT_ID")
	}
	if projectID == "" {
		projectID = os.Getenv("GOOGLE_CLOUD_PROJECT")
	}
	if projectID == "" {
		projectID = os.Getenv("GCLOUD_PROJECT")
	}
	if projectID == "" {
		projectID = DefaultProjectID
	}

	location := os.Getenv("VERTEX_LOCATION")
	if location == "" {
		location = os.Getenv("LOCATION")
	}
	if location == "" {
		location = DefaultLocation
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	modelID := os.Getenv("VERTEX_MODEL_ID")
	if modelID == "" {
		modelID = ModelGeminiFlash
	}

	// Enforce strict model invariant: Exclusively use gemini-3.8-flash.
	if modelID == ForbiddenModelPro {
		return nil, fmt.Errorf("invariant violation: %s is strictly forbidden. Exclusively use %s", ForbiddenModelPro, ModelGeminiFlash)
	}
	if modelID != ModelGeminiFlash {
		return nil, fmt.Errorf("invalid model %q: exclusively use %s", modelID, ModelGeminiFlash)
	}

	storeType := os.Getenv("MEMORY_STORE_TYPE")
	if storeType == "" {
		storeType = "memory"
	}

	maxBundleSize := MaxBundleSizeBytes
	if customSize := os.Getenv("MAX_BUNDLE_SIZE_BYTES"); customSize != "" {
		if parsed, err := strconv.Atoi(customSize); err == nil && parsed > 0 && parsed <= MaxBundleSizeBytes {
			maxBundleSize = parsed
		}
	}

	firestoreDB := os.Getenv("FIRESTORE_DATABASE")
	if firestoreDB == "" {
		firestoreDB = "(default)"
	}

	vertexEndpoint := os.Getenv("VERTEX_AI_ENDPOINT")
	if vertexEndpoint == "" {
		if location == "global" {
			vertexEndpoint = "https://aiplatform.googleapis.com"
		} else {
			vertexEndpoint = fmt.Sprintf("https://%s-aiplatform.googleapis.com", location)
		}
	}

	return &Config{
		ProjectID:          projectID,
		Location:           location,
		ModelID:            modelID,
		Port:               port,
		AuthMode:           "ADC",
		MaxBundleSizeBytes: maxBundleSize,
		StoreType:          storeType,
		FirestoreDatabase:  firestoreDB,
		VertexEndpoint:     vertexEndpoint,
	}, nil
}
