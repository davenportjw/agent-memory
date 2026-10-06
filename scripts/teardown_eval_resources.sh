#!/usr/bin/env bash
set -euo pipefail

# Automated resource teardown script for Distributed AI test harnesses and benchmark eval runs.
# Adheres to the RESOURCE LIFECYCLE & TEARDOWN rule.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source .env if present
if [ -f "${ROOT_DIR}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

PROJECT_ID="${GCP_PROJECT:-${PROJECT_ID:-}}"
BUCKET_NAME="${EVAL_BUCKET:-${GCS_STAGING_BUCKET:-}}"
PREFIX="evals/"

if [ -z "${PROJECT_ID}" ] || [ -z "${BUCKET_NAME}" ]; then
  echo "Error: GCP_PROJECT (or PROJECT_ID) and EVAL_BUCKET (or GCS_STAGING_BUCKET) must be configured in environment or .env file." >&2
  exit 1
fi

echo "=================================================="
echo "Starting Teardown of Test & Eval Resources"
echo "Target Project: ${PROJECT_ID}"
echo "Target Bucket:  gs://${BUCKET_NAME}/${PREFIX}"
echo "=================================================="

# 1. Clean up ephemeral evaluation artifacts in GCS staging bucket
if command -v gcloud &>/dev/null; then
  echo "Checking for ephemeral benchmark outputs in gs://${BUCKET_NAME}/${PREFIX}..."
  if gcloud storage ls --project "${PROJECT_ID}" "gs://${BUCKET_NAME}/${PREFIX}" &>/dev/null; then
    echo "Pruning temporary eval runs from GCS..."
    gcloud storage rm --project "${PROJECT_ID}" -r "gs://${BUCKET_NAME}/${PREFIX}**" || true
    echo "Cleaned GCS benchmark outputs."
  else
    echo "No ephemeral objects found under gs://${BUCKET_NAME}/${PREFIX}."
  fi
fi

# 2. Prune local scratch artifacts
SCRATCH_DIR="${ROOT_DIR}/server/tmp_evals"
if [ -d "${SCRATCH_DIR}" ]; then
  echo "Pruning local eval scratch directory: ${SCRATCH_DIR}..."
  rm -rf "${SCRATCH_DIR}"
fi

echo "=================================================="
echo "Teardown Complete. All ephemeral resources pruned."
echo "=================================================="
