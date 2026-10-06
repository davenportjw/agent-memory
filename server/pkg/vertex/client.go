package vertex

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"mult-agent-madness/server/pkg/config"
	"mult-agent-madness/server/pkg/models"
)

// Invariant model constant.
const (
	ExpectedModel = config.ModelGeminiFlash
)

// InlineData represents multimodal binary/base64 content (such as generated images).
type InlineData struct {
	MimeType string `json:"mimeType"`
	Data     string `json:"data"`
}

// Part represents a content chunk in Vertex AI requests/responses.
type Part struct {
	Text       string      `json:"text,omitempty"`
	InlineData *InlineData `json:"inlineData,omitempty"`
}

// Content represents message turns in Gemini conversations.
type Content struct {
	Role  string `json:"role,omitempty"`
	Parts []Part `json:"parts"`
}

// GenerationConfig controls decoding parameters.
type GenerationConfig struct {
	Temperature        *float64 `json:"temperature,omitempty"`
	MaxOutputTokens    int      `json:"maxOutputTokens,omitempty"`
	TopP               *float64 `json:"topP,omitempty"`
	ResponseMimeType   string   `json:"responseMimeType,omitempty"`
	ResponseModalities []string `json:"responseModalities,omitempty"`
}

// GenerateRequest defines the payload sent to Vertex AI Gemini.
type GenerateRequest struct {
	Contents          []Content         `json:"contents"`
	SystemInstruction *Content          `json:"systemInstruction,omitempty"`
	GenerationConfig  *GenerationConfig `json:"generationConfig,omitempty"`
}

// Candidate represents a generated candidate from Gemini.
type Candidate struct {
	Content      Content `json:"content"`
	FinishReason string  `json:"finishReason,omitempty"`
}

// UsageMetadata captures token counts.
type UsageMetadata struct {
	PromptTokenCount     int `json:"promptTokenCount"`
	CandidatesTokenCount int `json:"candidatesTokenCount"`
	TotalTokenCount      int `json:"totalTokenCount"`
}

// GenerateResponse is the response from Vertex AI Gemini generateContent.
type GenerateResponse struct {
	Candidates    []Candidate    `json:"candidates"`
	UsageMetadata *UsageMetadata `json:"usageMetadata,omitempty"`
}

// FirstText extracts the textual output from the first candidate.
func (r *GenerateResponse) FirstText() string {
	if r == nil || len(r.Candidates) == 0 {
		return ""
	}
	var sb strings.Builder
	for _, part := range r.Candidates[0].Content.Parts {
		sb.WriteString(part.Text)
	}
	return sb.String()
}

// Client defines the interface for interacting with Vertex AI.
type Client interface {
	GenerateContent(ctx context.Context, req *GenerateRequest) (*GenerateResponse, error)
	StreamGenerateContent(ctx context.Context, req *GenerateRequest, onChunk func(chunk string) error) (*GenerateResponse, error)
	GenerateImage(ctx context.Context, req *models.ImageGenerationRequest) (*models.ImageGenerationResponse, error)
	GetModelID() string
}

// TokenSource provides OAuth2 Bearer tokens using ADC.
type TokenSource interface {
	Token(ctx context.Context) (string, error)
}

// ADCTokenSource implements Google Cloud Application Default Credentials resolution.
type ADCTokenSource struct {
	mu          sync.Mutex
	cachedToken string
	expiresAt   time.Time
	httpClient  *http.Client
}

// NewADCTokenSource creates an ADC token provider.
func NewADCTokenSource(client *http.Client) *ADCTokenSource {
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	return &ADCTokenSource{httpClient: client}
}

// Token returns a valid Bearer token via Google Application Default Credentials.
// Invariant: Never checks or requires GEMINI_API_KEY.
func (ts *ADCTokenSource) Token(ctx context.Context) (string, error) {
	ts.mu.Lock()
	defer ts.mu.Unlock()

	// Return cached token if valid for at least another 60 seconds
	if ts.cachedToken != "" && time.Now().Add(60*time.Second).Before(ts.expiresAt) {
		return ts.cachedToken, nil
	}

	// 1. Check direct access token environment variable
	if directToken := os.Getenv("GOOGLE_OAUTH_ACCESS_TOKEN"); directToken != "" {
		ts.cachedToken = directToken
		ts.expiresAt = time.Now().Add(30 * time.Minute)
		return ts.cachedToken, nil
	}
	if directToken := os.Getenv("CLOUDSDK_AUTH_ACCESS_TOKEN"); directToken != "" {
		ts.cachedToken = directToken
		ts.expiresAt = time.Now().Add(30 * time.Minute)
		return ts.cachedToken, nil
	}

	// 2. Query Cloud Run / GCE instance metadata server
	token, expiry, err := ts.fetchFromMetadataServer(ctx)
	if err == nil && token != "" {
		ts.cachedToken = token
		ts.expiresAt = expiry
		return ts.cachedToken, nil
	}

	// 3. Check GOOGLE_APPLICATION_CREDENTIALS or default user credentials file
	credPath := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	if credPath == "" {
		if home, err := os.UserHomeDir(); err == nil {
			credPath = filepath.Join(home, ".config", "gcloud", "application_default_credentials.json")
		}
	}

	if credPath != "" {
		token, expiry, err = ts.fetchFromFileCredentials(ctx, credPath)
		if err == nil && token != "" {
			ts.cachedToken = token
			ts.expiresAt = expiry
			return ts.cachedToken, nil
		}
	}

	return "", fmt.Errorf("adc error: failed to obtain Google Cloud Application Default Credentials. Verify Cloud Run IAM service account or 'gcloud auth application-default login'")
}

func (ts *ADCTokenSource) fetchFromMetadataServer(ctx context.Context) (string, time.Time, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token", nil)
	if err != nil {
		return "", time.Time{}, err
	}
	req.Header.Set("Metadata-Flavor", "Google")

	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", time.Time{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", time.Time{}, fmt.Errorf("metadata server returned status %d", resp.StatusCode)
	}

	var metaToken struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		TokenType   string `json:"token_type"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&metaToken); err != nil {
		return "", time.Time{}, err
	}

	expiry := time.Now().Add(time.Duration(metaToken.ExpiresIn) * time.Second)
	return metaToken.AccessToken, expiry, nil
}

func (ts *ADCTokenSource) fetchFromFileCredentials(ctx context.Context, path string) (string, time.Time, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", time.Time{}, err
	}

	var cred struct {
		Type         string `json:"type"`
		ClientID     string `json:"client_id"`
		ClientSecret string `json:"client_secret"`
		RefreshToken string `json:"refresh_token"`
		PrivateKey   string `json:"private_key"`
		ClientEmail  string `json:"client_email"`
		TokenURI     string `json:"token_uri"`
	}
	if err := json.Unmarshal(data, &cred); err != nil {
		return "", time.Time{}, err
	}

	tokenEndpoint := cred.TokenURI
	if tokenEndpoint == "" {
		tokenEndpoint = "https://oauth2.googleapis.com/token"
	}

	// Authorized User Credentials with Refresh Token
	if cred.Type == "authorized_user" && cred.RefreshToken != "" {
		form := url.Values{}
		form.Set("client_id", cred.ClientID)
		form.Set("client_secret", cred.ClientSecret)
		form.Set("refresh_token", cred.RefreshToken)
		form.Set("grant_type", "refresh_token")

		req, err := http.NewRequestWithContext(ctx, "POST", tokenEndpoint, strings.NewReader(form.Encode()))
		if err != nil {
			return "", time.Time{}, err
		}
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

		resp, err := ts.httpClient.Do(req)
		if err != nil {
			return "", time.Time{}, err
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			return "", time.Time{}, fmt.Errorf("refresh token error status %d: %s", resp.StatusCode, string(body))
		}

		var tokenResp struct {
			AccessToken string `json:"access_token"`
			ExpiresIn   int    `json:"expires_in"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
			return "", time.Time{}, err
		}

		return tokenResp.AccessToken, time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second), nil
	}

	return "", time.Time{}, fmt.Errorf("unsupported or incomplete credential type in %s", path)
}

// VertexClient implements Client for Google Cloud Vertex AI.
type VertexClient struct {
	cfg         *config.Config
	tokenSource TokenSource
	httpClient  *http.Client
}

// NewClient initializes a Vertex AI Gemini client.
// Strictly enforces 'gemini-3.8-flash'. Rejects 'gemini-3.8-pro'.
func NewClient(cfg *config.Config, httpClient *http.Client) (*VertexClient, error) {
	if cfg.ModelID == config.ForbiddenModelPro {
		return nil, fmt.Errorf("invariant violation: %s is strictly forbidden. Exclusively use %s", config.ForbiddenModelPro, config.ModelGeminiFlash)
	}
	if cfg.ModelID != config.ModelGeminiFlash {
		return nil, fmt.Errorf("invalid model %q: exclusively use %s", cfg.ModelID, config.ModelGeminiFlash)
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 60 * time.Second}
	}

	return &VertexClient{
		cfg:         cfg,
		tokenSource: NewADCTokenSource(httpClient),
		httpClient:  httpClient,
	}, nil
}

// SetTokenSource allows injecting a custom token source (e.g. for testing).
func (c *VertexClient) SetTokenSource(ts TokenSource) {
	c.tokenSource = ts
}

// GetModelID returns the active model ID (strictly gemini-3.8-flash).
func (c *VertexClient) GetModelID() string {
	return c.cfg.ModelID
}

// endpoint returns the full Vertex AI REST endpoint for generateContent or streamGenerateContent.
func (c *VertexClient) endpoint(action string) string {
	base := strings.TrimRight(c.cfg.VertexEndpoint, "/")
	return fmt.Sprintf("%s/v1/projects/%s/locations/%s/publishers/google/models/%s:%s",
		base, c.cfg.ProjectID, c.cfg.Location, c.cfg.ModelID, action)
}

// GenerateContent sends a single turn or multi-turn structured request to Vertex AI Gemini 3.8 Flash.
func (c *VertexClient) GenerateContent(ctx context.Context, req *GenerateRequest) (*GenerateResponse, error) {
	if c.cfg.ModelID != config.ModelGeminiFlash {
		return nil, fmt.Errorf("invariant violation: client model must be %s", config.ModelGeminiFlash)
	}

	token, err := c.tokenSource.Token(ctx)
	if err != nil {
		return nil, fmt.Errorf("adc token failure: %w", err)
	}

	reqBody, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal generate request: %w", err)
	}

	endpoint := c.endpoint("generateContent")
	httpReq, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json; charset=utf-8")
	httpReq.Header.Set("Authorization", "Bearer "+token)

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("vertex api call failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("vertex api error (HTTP %d): %s", resp.StatusCode, string(body))
	}

	var genResp GenerateResponse
	if err := json.NewDecoder(resp.Body).Decode(&genResp); err != nil {
		return nil, fmt.Errorf("failed to decode vertex response: %w", err)
	}

	return &genResp, nil
}

// StreamGenerateContent streams server-sent events (SSE) from Vertex AI Gemini 3.8 Flash.
func (c *VertexClient) StreamGenerateContent(ctx context.Context, req *GenerateRequest, onChunk func(chunk string) error) (*GenerateResponse, error) {
	if c.cfg.ModelID != config.ModelGeminiFlash {
		return nil, fmt.Errorf("invariant violation: client model must be %s", config.ModelGeminiFlash)
	}

	token, err := c.tokenSource.Token(ctx)
	if err != nil {
		return nil, fmt.Errorf("adc token failure: %w", err)
	}

	reqBody, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal stream request: %w", err)
	}

	endpoint := c.endpoint("streamGenerateContent") + "?alt=sse"
	httpReq, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create stream request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json; charset=utf-8")
	httpReq.Header.Set("Accept", "text/event-stream")
	httpReq.Header.Set("Authorization", "Bearer "+token)

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("vertex stream api call failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("vertex stream api error (HTTP %d): %s", resp.StatusCode, string(body))
	}

	var fullResponse GenerateResponse
	var accumulatedText strings.Builder

	reader := bufio.NewReader(resp.Body)
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, fmt.Errorf("error reading sse stream: %w", err)
		}

		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "data: ") {
			continue
		}

		dataJSON := strings.TrimPrefix(line, "data: ")
		if dataJSON == "[DONE]" {
			break
		}

		var chunkResp GenerateResponse
		if err := json.Unmarshal([]byte(dataJSON), &chunkResp); err != nil {
			continue
		}

		chunkText := chunkResp.FirstText()
		if chunkText != "" {
			accumulatedText.WriteString(chunkText)
			if onChunk != nil {
				if err := onChunk(chunkText); err != nil {
					return nil, err
				}
			}
		}

		if len(chunkResp.Candidates) > 0 {
			fullResponse.Candidates = chunkResp.Candidates
		}
		if chunkResp.UsageMetadata != nil {
			fullResponse.UsageMetadata = chunkResp.UsageMetadata
		}
	}

	// Ensure the full accumulated text is represented in fullResponse
	if len(fullResponse.Candidates) == 0 && accumulatedText.Len() > 0 {
		fullResponse.Candidates = []Candidate{
			{
				Content: Content{
					Role:  "model",
					Parts: []Part{{Text: accumulatedText.String()}},
				},
				FinishReason: "STOP",
			},
		}
	}

	return &fullResponse, nil
}

// GenerateImage invokes Nano Banana 2 Lite (gemini-3.1-flash-lite-image) on Vertex AI
// with responseModalities: ["TEXT", "IMAGE"] using ADC Bearer token authorization.
func (c *VertexClient) GenerateImage(ctx context.Context, req *models.ImageGenerationRequest) (*models.ImageGenerationResponse, error) {
	if req == nil || strings.TrimSpace(req.Prompt) == "" {
		return nil, errors.New("image prompt cannot be empty")
	}

	start := time.Now()
	token, err := c.tokenSource.Token(ctx)
	if err != nil {
		return nil, fmt.Errorf("adc token failure: %w", err)
	}

	promptText := req.Prompt
	if len(req.ContextAnchors) > 0 {
		promptText = fmt.Sprintf("%s\nContext anchors: %s", promptText, strings.Join(req.ContextAnchors, "; "))
	}

	vReq := GenerateRequest{
		Contents: []Content{
			{
				Role: "user",
				Parts: []Part{
					{Text: promptText},
				},
			},
		},
		GenerationConfig: &GenerationConfig{
			ResponseModalities: []string{"TEXT", "IMAGE"},
		},
	}

	reqBody, err := json.Marshal(vReq)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal image generate request: %w", err)
	}

	// Invariant endpoint for Nano Banana 2 Lite
	endpoint := fmt.Sprintf("%s/v1/projects/%s/locations/%s/publishers/google/models/%s:generateContent",
		strings.TrimRight(c.cfg.VertexEndpoint, "/"),
		c.cfg.ProjectID,
		c.cfg.Location,
		config.ModelNanoBanana2Lite,
	)

	httpReq, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json; charset=utf-8")
	httpReq.Header.Set("Authorization", "Bearer "+token)

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("vertex nano banana 2 lite call failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("vertex nano banana 2 lite error (HTTP %d): %s", resp.StatusCode, string(body))
	}

	var genResp GenerateResponse
	if err := json.NewDecoder(resp.Body).Decode(&genResp); err != nil {
		return nil, fmt.Errorf("failed to decode vertex image response: %w", err)
	}

	var imageB64 string
	var mimeType string
	for _, cand := range genResp.Candidates {
		for _, p := range cand.Content.Parts {
			if p.InlineData != nil && p.InlineData.Data != "" {
				imageB64 = p.InlineData.Data
				mimeType = p.InlineData.MimeType
				if mimeType == "" {
					mimeType = "image/jpeg"
				}
				break
			}
		}
		if imageB64 != "" {
			break
		}
	}

	if imageB64 == "" {
		return nil, errors.New("no image data returned in candidate parts from nano banana 2 lite")
	}

	latency := time.Since(start).Milliseconds()
	egressBytes := len(imageB64)

	return &models.ImageGenerationResponse{
		ImageBase64: imageB64,
		MimeType:    mimeType,
		ModelID:     config.ModelNanoBanana2Lite,
		Prompt:      req.Prompt,
		LatencyMs:   latency,
		EgressBytes: egressBytes,
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}
