# ==========================================
# Multi-Stage Scratch Dockerfile for Cloud Run
# Architecture: Distributed AI Backend
# Model: gemini-3.8-flash (strictly no pro)
# ==========================================

# Stage 1: Build binary with Go alpine
FROM golang:alpine AS builder

WORKDIR /src

# Install CA certificates for secure Vertex AI TLS connections
RUN apk --no-cache add ca-certificates tzdata

# Copy module definitions
COPY go.mod go.sum ./

# Copy server source code and shared assets
COPY cmd/ ./cmd/
COPY pkg/ ./pkg/

# Build static minimal Go binary
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-w -s" -o /bin/server ./cmd/server

# Stage 2: Minimal Scratch Container
FROM scratch

# Copy root CA certificates for HTTPS/TLS requests to Vertex AI
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy compiled binary
COPY --from=builder /bin/server /server

# Cloud Run environment defaults
ENV PORT=8080 \
    GCP_REGION=us-central1 \
    LOCATION=global \
    VERTEX_LOCATION=global \
    VERTEX_MODEL_ID=gemini-3.8-flash

EXPOSE 8080

# Cloud Run container entrypoint
ENTRYPOINT ["/server"]
