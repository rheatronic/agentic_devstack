# =============================================================================
# llama-server — CUDA build from source
# Base: nvidia/cuda 12.4 devel (matches win-cuda-12.4 release artifacts and
#       the A6000 driver stack you already have confirmed working).
#
# Build args you can override on the host:
#   LLAMA_TAG          — llama.cpp git tag to pin (default: b9204)
#   CUDA_ARCH          — semicolon-separated CMake CUDA arch list
#                        A6000 = sm_86; keep "86" unless you swap GPUs
#   BUILD_JOBS         — parallel make jobs (default: nproc)
# =============================================================================

ARG CUDA_IMAGE=nvidia/cuda:12.4.1-devel-ubuntu22.04
FROM ${CUDA_IMAGE} AS builder

ARG LLAMA_TAG=b9204
ARG CUDA_ARCH=86
ARG BUILD_JOBS=0          # 0 → $(nproc)

# ── build dependencies ────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        cmake \
        ninja-build \
        ccache \
        libssl-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── clone at the pinned tag only (shallow = fast) ────────────────────────────
WORKDIR /src
RUN git clone --depth 1 --branch ${LLAMA_TAG} \
        https://github.com/ggml-org/llama.cpp .

# ── configure ─────────────────────────────────────────────────────────────────
#  -DGGML_CUDA=ON           → CUDA backend
#  -DCMAKE_CUDA_ARCHITECTURES → compile only for A6000 (sm_86); saves ~10 min
#  -DGGML_NATIVE=OFF        → don't try to detect host GPU inside Docker
#  -DLLAMA_SERVER=ON        → build the HTTP server binary
#  -DBUILD_SHARED_LIBS=OFF  → fully static; no LD_LIBRARY_PATH headaches
RUN cmake -B build \
          -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DGGML_CUDA=ON \
          -DGGML_NATIVE=OFF \
          -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH}" \
          -DBUILD_SHARED_LIBS=OFF \
          -DLLAMA_BUILD_SERVER=ON

# ── compile ───────────────────────────────────────────────────────────────────
RUN if [ "${BUILD_JOBS}" = "0" ]; then \
        cmake --build build --target llama-server -j$(nproc); \
    else \
        cmake --build build --target llama-server -j${BUILD_JOBS}; \
    fi

# =============================================================================
# Runtime stage — minimal CUDA runtime, no compiler chain
# =============================================================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS runtime

# curl for the healthcheck; libgomp for OpenMP thread pool inside ggml
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/build/bin/llama-server /usr/local/bin/llama-server

# ── model volume ──────────────────────────────────────────────────────────────
# The host bind-mounts /data/models/gguf here at runtime.
# Nothing is baked into the image — models live on the host disk.
VOLUME ["/models"]

# ── entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000

# Liveness probe — docker compose / healthcheck block uses this
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -sf http://localhost:8000/health || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
