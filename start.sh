#!/bin/bash
set -e

if [ -z "$GITHUB_PAT" ]; then
  echo "ERROR: GITHUB_PAT not set"
  exit 1
fi

if [ -z "$GITHUB_REPO_OWNER" ]; then
  echo "ERROR: GITHUB_REPO_OWNER not set"
  exit 1
fi

if [ -z "$GITHUB_REPO_NAME" ]; then
  echo "ERROR: GITHUB_REPO_NAME not set"
  exit 1
fi

# Add user to docker group
if [ ! -e /var/run/docker.sock ]; then
  echo "Docker socket not found, skipping docker group addition"
  exit 1
fi
sudo groupadd -g $(stat -c "%g" /var/run/docker.sock) docker-host
sudo usermod -aG docker-host runner

# API endpoint para token
GITHUB_API_URL="https://api.github.com"
GITHUB_TOKEN_URL="$GITHUB_API_URL/repos/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME/actions/runners/registration-token"

# URL do repositório (usado pelo config.sh)
GITHUB_REPO_URL="https://github.com/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"

# Function to setup new runner
runnerSetup() {

  echo "Runner not found, setting up new runner..."

  GITHUB_RUNNER_NAME="docker-runner-$(hostname)-$(date +%s)"

  echo "Requesting runner token..."

  TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "${GITHUB_TOKEN_URL}" \
  | jq -r .token)

  if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo "ERROR: Failed to obtain runner token"
    exit 1
  else
    echo "$TOKEN" > .token
  fi

  echo "Configuring runner..."

  ./config.sh \
  --url "${GITHUB_REPO_URL}" \
  --token "${TOKEN}" \
  --name "${GITHUB_RUNNER_NAME}" \
  --labels docker,linux \
  --work _work \
  --unattended \
  --replace

  cat << 'EOF' > script.sh
#!/bin/bash

# Interrompe a execução em caso de erro
set -e

# Verifica se a variável de ambiente necessária existe
if [[ -z "$RUNNER_TOKEN" ]]; then
    echo "Erro: A variável RUNNER_TOKEN não está definida." >&2
    exit 1
fi

echo "Iniciando a remoção do runner..."

# Executa a remoção de forma não interativa
if ./config.sh remove --token "$RUNNER_TOKEN"; then
    echo "Runner removido com sucesso."
else
    echo "Falha ao remover o runner." >&2
    exit 1
fi
EOF

  # Garante que o arquivo tenha permissão de execução
  chmod +x script.sh

  echo "Runner configured successfully"
  echo ""
}

# Function to cleanup runner
cleanup() {

  echo "Removing runner..."

  REMOVE_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github+json" \
    "$GITHUB_API_URL/repos/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME/actions/runners/remove-token" \
    | jq -r .token)

  if [ -n "$REMOVE_TOKEN" ] && [ "$REMOVE_TOKEN" != "null" ]; then
    ./config.sh remove --token "$REMOVE_TOKEN"
  fi

  echo "Runner removed"
  echo ""
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

if [ -f .token ] && [ -f .runner ]; then
  TOKEN=$(cat .token)
  GITHUB_RUNNER_NAME=$(jq -r .agentName < .runner)
else
  runnerSetup
fi

echo "Starting runner..."
echo ""

echo "-------------------------------------"
echo "Github API URL: $GITHUB_API_URL"
echo "Github Repo URL: $GITHUB_REPO_URL"
echo "GITHUB_REPO_OWNER: $GITHUB_REPO_OWNER"
echo "GITHUB_REPO_NAME: $GITHUB_REPO_NAME"
echo "RUNNER NAME: $GITHUB_RUNNER_NAME"
echo "TOKEN: $TOKEN"
echo "-------------------------------------"
echo ""

./run.sh &

wait $!