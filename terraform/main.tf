locals {
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    system      = "distributed-ai"
  }

  required_services = [
    "run.googleapis.com",
    "firestore.googleapis.com",
    "artifactregistry.googleapis.com",
    "aiplatform.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "firebase.googleapis.com",
    "firebaseremoteconfig.googleapis.com",
    "firebaserules.googleapis.com"
  ]

  service_account_roles = [
    "roles/aiplatform.user",
    "roles/datastore.user",
    "roles/storage.objectAdmin",
    "roles/run.invoker"
  ]
}

# ------------------------------------------------------------------------------
# Google Cloud Service APIs
# ------------------------------------------------------------------------------
resource "google_project_service" "enabled_apis" {
  for_each           = var.enable_apis ? toset(local.required_services) : toset([])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ------------------------------------------------------------------------------
# Least-Privilege IAM Service Account
# ------------------------------------------------------------------------------
resource "google_service_account" "distributed_ai_sa" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Distributed AI Service Account"
  description  = "Least-privilege runtime service account for distributed-ai-backend"

  depends_on = [
    google_project_service.enabled_apis
  ]
}

resource "google_project_iam_member" "sa_roles" {
  for_each = toset(local.service_account_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.distributed_ai_sa.email}"
}

# ------------------------------------------------------------------------------
# Artifact Registry Repository (Docker format)
# ------------------------------------------------------------------------------
resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo_id
  description   = "Artifact Registry repository for distributed-ai-backend Docker images"
  format        = "DOCKER"
  labels        = local.common_labels

  depends_on = [
    google_project_service.enabled_apis
  ]
}

# ------------------------------------------------------------------------------
# Cloud Storage Bucket for Vertex AI Staging and Eval Reports
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "vertex_staging" {
  project                     = var.project_id
  name                        = var.gcs_staging_bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }

  labels = local.common_labels

  depends_on = [
    google_project_service.enabled_apis
  ]
}

# ------------------------------------------------------------------------------
# Firestore Database in Native Mode
# ------------------------------------------------------------------------------
resource "google_firestore_database" "database" {
  project                 = var.project_id
  name                    = var.firestore_database_name
  location_id             = var.region
  type                    = "FIRESTORE_NATIVE"
  delete_protection_state = "DELETE_PROTECTION_DISABLED"
  deletion_policy         = "DELETE"

  depends_on = [
    google_project_service.enabled_apis
  ]
}

# ------------------------------------------------------------------------------
# Cloud Run v2 Service for Distributed AI Backend
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "backend" {
  name     = var.cloud_run_service_name
  location = var.region
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.distributed_ai_sa.email

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = var.backend_image

      ports {
        container_port = var.cloud_run_container_port
      }

      resources {
        limits = {
          cpu    = var.cloud_run_cpu
          memory = var.cloud_run_memory
        }
      }

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "REGION"
        value = var.region
      }
      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
      env {
        name  = "FIRESTORE_DATABASE"
        value = google_firestore_database.database.name
      }
      env {
        name  = "STAGING_BUCKET"
        value = google_storage_bucket.vertex_staging.name
      }
      env {
        name  = "MODEL_NAME"
        value = "gemini-3.8-flash"
      }
      env {
        name  = "PORT"
        value = tostring(var.cloud_run_container_port)
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = local.common_labels

  depends_on = [
    google_project_service.enabled_apis,
    google_project_iam_member.sa_roles
  ]
}

# ------------------------------------------------------------------------------
# Cloud Run Invocation Access Policy (Backend)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = var.project_id
  location = google_cloud_run_v2_service.backend.location
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ------------------------------------------------------------------------------
# Cloud Run v2 Service: Distributed AI Flutter Web WASM Frontend
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "frontend" {
  project  = var.project_id
  name     = var.cloud_run_frontend_service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    containers {
      image = var.frontend_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "256Mi"
        }
      }

      env {
        name  = "PORT"
        value = "8080"
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = local.common_labels

  depends_on = [
    google_project_service.enabled_apis
  ]
}

resource "google_cloud_run_v2_service_iam_member" "frontend_public_access" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = var.project_id
  location = google_cloud_run_v2_service.frontend.location
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

