output "project_id" {
  description = "Google Cloud Platform project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP deployment region"
  value       = var.region
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run v2 service"
  value       = google_cloud_run_v2_service.backend.name
}

output "cloud_run_service_id" {
  description = "Resource ID of the Cloud Run v2 service"
  value       = google_cloud_run_v2_service.backend.id
}

output "cloud_run_service_uri" {
  description = "Primary URL endpoint of the Cloud Run v2 service"
  value       = google_cloud_run_v2_service.backend.uri
}

output "firestore_database_name" {
  description = "Firestore database name"
  value       = google_firestore_database.database.name
}

output "firestore_database_id" {
  description = "Resource ID of the Firestore database"
  value       = google_firestore_database.database.id
}

output "artifact_registry_repo_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

output "artifact_registry_repo_name" {
  description = "Artifact Registry full resource name"
  value       = google_artifact_registry_repository.docker_repo.name
}

output "artifact_registry_docker_url" {
  description = "Docker repository image URL prefix"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

output "vertex_staging_bucket_name" {
  description = "Cloud Storage bucket name for Vertex AI staging"
  value       = google_storage_bucket.vertex_staging.name
}

output "vertex_staging_bucket_url" {
  description = "Cloud Storage bucket URL"
  value       = google_storage_bucket.vertex_staging.url
}

output "service_account_id" {
  description = "Service account resource ID"
  value       = google_service_account.distributed_ai_sa.id
}

output "service_account_email" {
  description = "Service account email address"
  value       = google_service_account.distributed_ai_sa.email
}

output "service_account_roles" {
  description = "IAM roles granted to the runtime service account"
  value       = local.service_account_roles
}

output "cloud_run_frontend_service_uri" {
  description = "Primary URL endpoint of the Cloud Run v2 Flutter Web WASM frontend"
  value       = google_cloud_run_v2_service.frontend.uri
}

