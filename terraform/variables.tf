variable "project_id" {
  description = "Google Cloud Platform project ID"
  type        = string
  default     = "your-gcp-project-id"
}

variable "region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment identifier (e.g. dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run v2 service for distributed AI backend"
  type        = string
  default     = "distributed-ai-backend"
}

variable "backend_image" {
  description = "Container image URI for Cloud Run service (defaults to public hello image as bootstrap placeholder)"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "artifact_registry_repo_id" {
  description = "Artifact Registry Docker repository ID"
  type        = string
  default     = "distributed-ai-backend"
}

variable "firestore_database_name" {
  description = "Firestore database ID in Native mode ('(default)' or named 'durable-memory')"
  type        = string
  default     = "(default)"
}

variable "gcs_staging_bucket_name" {
  description = "Cloud Storage bucket name for Vertex AI staging and evaluation artifacts"
  type        = string
  default     = "your-gcp-project-id-vertex-staging"
}

variable "service_account_id" {
  description = "Service account ID for runtime execution with least privilege"
  type        = string
  default     = "distributed-ai-sa"
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run container instances"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run container instances"
  type        = number
  default     = 10
}

variable "cloud_run_cpu" {
  description = "CPU allocation per container instance"
  type        = string
  default     = "1000m"
}

variable "cloud_run_memory" {
  description = "Memory allocation per container instance"
  type        = string
  default     = "512Mi"
}

variable "cloud_run_container_port" {
  description = "Port on which the backend container listens"
  type        = number
  default     = 8080
}

variable "allow_unauthenticated" {
  description = "Whether to allow unauthenticated invocations on the Cloud Run service"
  type        = bool
  default     = true
}

variable "enable_apis" {
  description = "Whether to enable necessary GCP APIs via Terraform"
  type        = bool
  default     = true
}

variable "cloud_run_frontend_service_name" {
  description = "Name of the Cloud Run v2 service for distributed AI Flutter web frontend"
  type        = string
  default     = "distributed-ai-frontend"
}

variable "frontend_image" {
  description = "Container image URI for Flutter Web WASM frontend"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

