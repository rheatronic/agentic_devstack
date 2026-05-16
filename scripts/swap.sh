#!/usr/bin/env bash
# =============================================================================
# scripts/swap.sh — hot-swap between agentic and autocomplete stacks
#
# Usage:
#   ./scripts/swap.sh agentic        # llama-server + litellm
#   ./scripts/swap.sh autocomplete   # vllm + litellm
#   ./scripts/swap.sh proxy          # litellm only (both backends stopped)
#   ./scripts/swap.sh status         # show running containers
#
# Swap time: ~60–120s (VRAM flush + container start + model load)
# =============================================================================

set -euo pipefail

COMPOSE="docker compose"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

usage() {
  echo "Usage: $0 {agentic|autocomplete|proxy|status}"
  exit 1
}

[[ $# -lt 1 ]] && usage

TARGET="${1}"

case "${TARGET}" in

  agentic)
    echo "==> Stopping autocomplete stack (if running)..."
    ${COMPOSE} --profile autocomplete down --timeout 30 2>/dev/null || true

    echo "==> Starting agentic stack (llama-server + litellm)..."
    ${COMPOSE} --profile agentic up -d

    echo "==> Waiting for llama-server to be healthy..."
    for i in $(seq 1 24); do
      if docker inspect --format='{{.State.Health.Status}}' llama-server 2>/dev/null | grep -q "healthy"; then
        echo "    llama-server is healthy."
        break
      fi
      echo "    Attempt ${i}/24 — sleeping 5s..."
      sleep 5
    done

    echo "==> Active profile: agentic"
    ${COMPOSE} ps
    ;;

  autocomplete)
    echo "==> Stopping agentic stack (if running)..."
    ${COMPOSE} --profile agentic down --timeout 30 2>/dev/null || true

    echo "==> Starting autocomplete stack (vllm + litellm)..."
    ${COMPOSE} --profile autocomplete up -d

    echo "==> Waiting for vllm to be healthy..."
    for i in $(seq 1 36); do
      if docker inspect --format='{{.State.Health.Status}}' vllm 2>/dev/null | grep -q "healthy"; then
        echo "    vllm is healthy."
        break
      fi
      echo "    Attempt ${i}/36 — sleeping 5s..."
      sleep 5
    done

    echo "==> Active profile: autocomplete"
    ${COMPOSE} ps
    ;;

  proxy)
    echo "==> Stopping all inference backends..."
    ${COMPOSE} --profile agentic down --timeout 30 2>/dev/null || true
    ${COMPOSE} --profile autocomplete down --timeout 30 2>/dev/null || true

    echo "==> Starting litellm proxy only..."
    ${COMPOSE} --profile proxy up -d

    echo "==> Active profile: proxy only"
    ${COMPOSE} ps
    ;;

  status)
    ${COMPOSE} ps
    ;;

  *)
    usage
    ;;
esac
