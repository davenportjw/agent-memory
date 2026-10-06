# Multi-stage Dockerfile for Flutter Web WASM on Cloud Run
FROM golang:alpine AS builder

WORKDIR /src
COPY web_server/main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-w -s" -o /bin/webserver main.go

FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /bin/webserver /webserver
COPY build/web /app/web

ENV PORT=8080 \
    STATIC_DIR=/app/web

EXPOSE 8080

ENTRYPOINT ["/webserver"]
