# llm-stack

Local multi-model LLM stack on Ubuntu 24.04 + RTX A6000 (48GB VRAM).

## Architecture

| Service | Port | Profile | Role |
|---------|------|---------|------|
| `llama-server` | `127.0.0.1:8000` | `agentic` | Qwen3-Coder-Next (GGUF MoE, agentic coding) |
| `vllm` | `127.0.0.1:8001` | `autocomplete` | Qwen2.5-Coder (tab autocomplete) |
| `litellm` | `0.0.0.0:4000` | all | OpenAI-compat gateway, LAN-exposed |

Models never run simultaneously — swap with `./scripts/swap.sh`.

## Quick start

```bash
# 1. Secrets
cp .env.example .env
./scripts/gen-secrets.sh          # generates LITELLM_* keys
$EDITOR .env                       # add ANTHROPIC_API_KEY, set model paths

# 2. Start agentic stack
./scripts/swap.sh agentic

# 3. Verify
curl http://localhost:4000/health/liveliness
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer $(grep LITELLM_MASTER_KEY .env | cut -d= -f2)"
```

## Hot-swap

```bash
./scripts/swap.sh agentic       # llama-server + litellm  (~60-90s)
./scripts/swap.sh autocomplete  # vllm + litellm          (~90-120s)
./scripts/swap.sh proxy         # litellm only (no inference)
./scripts/swap.sh status        # show running containers
```

## Deployment stages

- [x] **Stage 1** — Project structure + `.env` secrets baseline ← *you are here*
- [ ] **Stage 2** — llama-server container (Qwen3-Coder-Next, GGUF MoE offload)
- [ ] **Stage 3** — vLLM container (Qwen2.5-Coder)
- [ ] **Stage 4** — LiteLLM Proxy container + `config.yaml`
- [ ] **Stage 5** — Claude Code configuration
- [ ] **Stage 6** — Continue.dev configuration
- [ ] **Stage 7** — LAN exposure + firewall + end-to-end validation

## Model paths (host)

Set in `.env`:
- `LLAMA_MODEL_DIR` — directory containing your GGUF file(s)
- `LLAMA_MODEL_FILE` — active GGUF filename (e.g. `Qwen3-Coder-Next-UD-Q4_K_XL.gguf`)
- `VLLM_MODEL_DIR` — HuggingFace model cache root
- `VLLM_MODEL_NAME` — model ID relative to that root
