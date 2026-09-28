{{- /* claude-pattern-c-devcontainer/Dockerfile — minimal companion image for Pattern C's
     devcontainer.json (see that file's header for the full usage/opt-in note and scope).
     Non-root `claude` user; no credential-bearing host path is baked in or mounted here.
*/ -}}
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash claude

USER claude
WORKDIR /workspace
