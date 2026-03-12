#!/bin/bash
set -e

# Lê a versão do arquivo VERSION (fonte única de verdade)
RUNNER_VERSION=$(cat "$(dirname "$0")/VERSION" 2>/dev/null | tr -d '[:space:]') || {
  echo "[ERROR] Arquivo VERSION não encontrado." >&2; exit 1
}

source .env || true

if [ -z "$GITHUB_REPO_NAME" ]; then
    read -p "Enter the repository name: " GITHUB_REPO_NAME
fi

if [ -z "$GITHUB_REPO_OWNER" ]; then
    read -p "Enter the repository owner: " GITHUB_REPO_OWNER
fi

if [ -z "$GITHUB_PAT" ]; then
    read -p "Enter the personal access token: " GITHUB_PAT
fi

docker run -d --rm \
    --name github-runner \
    -e GITHUB_PAT=$GITHUB_PAT \
    -e GITHUB_REPO_OWNER=$GITHUB_REPO_OWNER \
    -e GITHUB_REPO_NAME=$GITHUB_REPO_NAME \
    -v /var/run/docker.sock:/var/run/docker.sock \
    juliansantosinfo/github-runner:"${RUNNER_VERSION}"