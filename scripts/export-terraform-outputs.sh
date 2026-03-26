#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"
OUTPUT_DIR="${ROOT_DIR}/ansible/generated"
OUTPUT_FILE="${OUTPUT_DIR}/terraform-output.json"

mkdir -p "${OUTPUT_DIR}"

terraform -chdir="${TERRAFORM_DIR}" output -json > "${OUTPUT_FILE}"

echo "[OK] Wrote Terraform outputs to ${OUTPUT_FILE}"
