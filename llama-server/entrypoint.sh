#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh — assemble llama-server arguments from environment variables
#
# Required env vars (set in .env / docker-compose.yml):
#   LLAMA_MODEL_FILE   — filename inside /models, e.g. Qwen3-Coder-Next-Q4_K_M.gguf
#
# Optional env vars with sensible defaults:
#   LLAMA_HOST             (default: 0.0.0.0)
#   LLAMA_PORT             (default: 8000)
#   LLAMA_N_GPU_LAYERS     (default: 999  → offload everything that fits)
#   LLAMA_CTX_SIZE         (default: 32768)
#   LLAMA_N_PARALLEL       (default: 1    → single concurrent request)
#   LLAMA_THREADS          (default: 8)
#   LLAMA_BATCH_SIZE       (default: 2048)
#   LLAMA_UBATCH_SIZE      (default: 512)
#   LLAMA_FLASH_ATTN       (default: 1    → enable flash attention)
#   LLAMA_OVERRIDE_TENSOR  (default: see below)
#
# MoE expert offload to RAM:
#   Qwen3-Coder-Next is a MoE model. Its expert weight tensors ("ffn_down_exps",
#   "ffn_gate_exps", "ffn_up_exps") do NOT all fit in 48 GB VRAM alongside the
#   attention layers when running large context. The --override-tensor flag tells
#   llama.cpp to keep those tensors on CPU RAM instead of VRAM, so only the
#   active experts are paged in per token.
#
#   The default pattern below routes all expert weight tensors to CPU.
#   You can override LLAMA_OVERRIDE_TENSOR entirely if your model uses
#   different tensor name patterns (check with llama-cli --info).
#
#   Format:  PATTERN=BACKEND   (repeatable, space-separated)
#   Example: "ffn_down_exps=CPU ffn_gate_exps=CPU ffn_up_exps=CPU"
#
#   To disable expert offload and keep everything on GPU:
#     LLAMA_OVERRIDE_TENSOR=""
# =============================================================================

set -euo pipefail

# ── validate required input ───────────────────────────────────────────────────
if [[ -z "${LLAMA_MODEL_FILE:-}" ]]; then
    echo "ERROR: LLAMA_MODEL_FILE is not set." >&2
    echo "       Set it in your .env file to the filename inside the model dir." >&2
    exit 1
fi

MODEL_PATH="/models/${LLAMA_MODEL_FILE}"

if [[ ! -f "${MODEL_PATH}" ]]; then
    echo "ERROR: Model file not found: ${MODEL_PATH}" >&2
    echo "       Check that LLAMA_MODEL_FILE matches a file in LLAMA_MODEL_DIR." >&2
    exit 1
fi

# ── settings ──────────────────────────────────────────────────────────────────
HOST="${LLAMA_HOST}"
PORT="${LLAMA_PORT}"
N_GPU_LAYERS="${LLAMA_N_GPU_LAYERS}"
CTX_SIZE="${LLAMA_CTX_SIZE}"
N_PARALLEL="${LLAMA_N_PARALLEL}"
THREADS="${LLAMA_THREADS}"
BATCH_SIZE="${LLAMA_BATCH_SIZE}"
UBATCH_SIZE="${LLAMA_UBATCH_SIZE}"
FLASH_ATTN="${LLAMA_FLASH_ATTN}"
NO_MMAP="${LLAMA_NO_MMAP}"
OVERRIDE_TENSOR="${LLAMA_OVERRIDE_TENSOR}"

# ── build argument array ──────────────────────────────────────────────────────
ARGS=(
    --model        "${MODEL_PATH}"
    --host         "${HOST}"
    --port         "${PORT}"
    --n-gpu-layers "${N_GPU_LAYERS}"
    --ctx-size     "${CTX_SIZE}"
    --parallel     "${N_PARALLEL}"
    --threads      "${THREADS}"
    --batch-size   "${BATCH_SIZE}"
    --ubatch-size  "${UBATCH_SIZE}"
)

# Flash attention — accepts: on, off, auto
if [[ -n "${LLAMA_FLASH_ATTN}" ]]; then
    ARGS+=( --flash-attn "${LLAMA_FLASH_ATTN}" )
fi

# mmap
if [[ "${NO_MMAP}" == "1" ]]; then
    ARGS+=( "--no-mmap" )
fi

# --override-tensor
ARGS+=( --override-tensor "${OVERRIDE_TENSOR}" )

# Pass any extra args from CMD / docker-compose command: block straight through
ARGS+=( "$@" )

# ── log the final command for troubleshooting ─────────────────────────────────
echo "=== llama-server startup ==="
echo "Model : ${MODEL_PATH}"
echo "Listen: ${HOST}:${PORT}"
echo "GPU layers: ${N_GPU_LAYERS}  ctx: ${CTX_SIZE}  fa: ${FLASH_ATTN}"
if [[ -n "${OVERRIDE_TENSOR}" ]]; then
    echo "MoE expert offload: ${OVERRIDE_TENSOR}"
fi
echo "Full command: llama-server ${ARGS[*]}"
echo "==========================="

exec llama-server "${ARGS[@]}"
