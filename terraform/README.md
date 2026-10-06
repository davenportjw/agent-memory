# Terraform Infrastructure: Distributed AI Platform

This directory provisions the Google Cloud Platform infrastructure for the **Distributed AI System**, supporting edge-to-cloud execution, durable memory consolidation, and LLM-as-a-Rater evaluation.

## Architecture & Provisioned Resources

| Resource | Terraform Resource Type | Identifier / Name | Purpose |
| :--- | :--- | :--- | :--- |
| **Cloud Run v2 Service** | `google_cloud_run_v2_service` | `distributed-ai-backend` | Golang Cloud Run service orchestrating Vertex AI & durable memory |
| **Firestore Native DB** | `google_firestore_database` | `(default)` (or `durable-memory`) | Native document store for `/episodes` and `/durable_nodes` |
| **Artifact Registry** | `google_artifact_registry_repository` | `distributed-ai-backend` | Docker registry hosting backend container releases |
| **Cloud Storage Bucket** | `google_storage_bucket` | `<project_id>-vertex-staging` | Versioned staging bucket for Vertex AI pipeline & eval reports |
| **Runtime Service Account** | `google_service_account` | `distributed-ai-sa` | Least-privilege identity used by Cloud Run instances |

## Least-Privilege IAM Matrix

The `distributed-ai-sa` service account is bound strictly to the minimal IAM roles needed for operation:

| Role | GCP IAM Role Name | Purpose |
| :--- | :--- | :--- |
| Vertex AI Invocations | `roles/aiplatform.user` | Invoking Gemini 3.8 Flash for reasoning, memory consolidation, & eval |
| Firestore Durable Graph | `roles/datastore.user` | Reading/writing episodes and durable knowledge graph nodes |
| GCS Artifact Staging | `roles/storage.objectAdmin` | Uploading and fetching evaluation logs and prompt staging datasets |
| Cloud Run Invocations | `roles/run.invoker` | Invoking Cloud Run service endpoints securely |

## Files in this Directory

- [`main.tf`](main.tf): Primary resource declarations (Cloud Run, Firestore, Artifact Registry, GCS, IAM).
- [`variables.tf`](variables.tf): Input variable definitions with strict defaults and typing.
- [`outputs.tf`](outputs.tf): Exported endpoints, resource IDs, and bucket names.
- [`versions.tf`](versions.tf): Terraform core (>= 1.5.0) and Google provider (~> 5.0) constraints.
- [`terraform.tfvars.example`](terraform.tfvars.example): Parameter values template for deployments.

## Quickstart & Deployment

### 1. Prerequisites
- Google Cloud SDK (`gcloud`) authenticated:
  ```bash
  gcloud auth login
  gcloud auth application-default login
  gcloud config set project <your-gcp-project-id>
  ```
- Terraform CLI (>= 1.5.0) installed.

### 2. Configuration
Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

### 3. Initialize & Validate
```bash
terraform fmt -check
terraform init
terraform validate
```

### 4. Review & Apply
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### 5. Build and Deploy Golang Backend Container
Once the Artifact Registry is created, push your container:
```bash
# Authenticate Docker to GCP Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Tag and push container (or use gcloud builds submit)
docker build -t us-central1-docker.pkg.dev/<your-gcp-project-id>/distributed-ai-backend/distributed-ai-backend:v1 ../server
docker push us-central1-docker.pkg.dev/<your-gcp-project-id>/distributed-ai-backend/distributed-ai-backend:v1

# Update terraform variable or run deploy
terraform apply -var="backend_image=us-central1-docker.pkg.dev/<your-gcp-project-id>/distributed-ai-backend/distributed-ai-backend:v1"
```
