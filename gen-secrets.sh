#!/usr/bin/env bash
# =============================================================================
# scripts/gen-secrets.sh
# One-time helper: generates LITELLM_MASTER_KEY and LITELLM_SALT_KEY,
# then patches them into .env in-place.
#
# Safe to re-run — will skip fields that already have real values.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} not found. Copy .env.example to .env first."
  exit 1
fi

patch_if_placeholder() {
  local key="$1"
  local new_val="$2"
  local current
  current=$(grep -E "^${key}=" "${ENV_FILE}" | cut -d= -f2-)

  if [[ "${current}" == *"REPLACE"* || -z "${current}" ]]; then
    sed -i "s|^${key}=.*|${key}=${new_val}|" "${ENV_FILE}"
    echo "  Generated ${key}"
  else
    echo "  Skipped ${key} (already set)"
  fi
}

echo "==> Generating LiteLLM secrets..."
MASTER_KEY="sk-local-$(openssl rand -hex 16)"
SALT_KEY="$(openssl rand -hex 32)"

patch_if_placeholder "LITELLM_MASTER_KEY" "${MASTER_KEY}"
patch_if_placeholder "LITELLM_SALT_KEY" "${SALT_KEY}"

echo ""
echo "Done. Fill in ANTHROPIC_API_KEY (and DEEPSEEK_API_KEY when ready) manually."
echo "Then set LLAMA_MODEL_DIR / VLLM_MODEL_DIR to your actual model paths."
