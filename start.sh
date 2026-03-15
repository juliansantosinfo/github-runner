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

# Check if docker socket exists
if [ ! -e /var/run/docker.sock ]; then
  echo "Docker socket not found, skipping docker group addition"
  exit 1
fi

# API endpoint para token
GITHUB_API_URL="https://api.github.com"
GITHUB_TOKEN_URL="$GITHUB_API_URL/repos/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME/actions/runners/registration-token"

# URL do repositório (usado pelo config.sh)
GITHUB_REPO_URL="https://github.com/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"

# Nome do runner
GITHUB_RUNNER_NAME="docker-runner-$(hostname)-$(date +%s)"

# Diretório de trabalho
WORK_DIR="_work"

# Se GITHUB_CUSTOM_WORK_PATH for true, cria um diretório de trabalho com o nome do runner
if [ "$GITHUB_CUSTOM_WORK_PATH" = true ]; then
  echo "Using work directory with container name: $GITHUB_RUNNER_NAME"
  WORK_DIR="_work/$GITHUB_RUNNER_NAME"
fi

# Criar diretório de trabalho se não existir
mkdir -p "$WORK_DIR"

# Configuração de privilégios e diretório de trabalho
if [ "$(id -u)" -eq 0 ] && [ "${RUNNER_ALLOW_RUNASROOT:-1}" != "1" ] && [ "${RUNNER_ALLOW_RUNASROOT:-1}" != "true" ]; then
  echo "Runner is running as root, but RUNNER_ALLOW_RUNASROOT is not true."
  echo "Performing root-only setup and switching to runner user..."
  echo ""

  # Adicionar usuário ao grupo docker se o socket existir
  if [ -e /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c "%g" /var/run/docker.sock)
    if ! getent group docker-host > /dev/null 2>&1; then
      groupadd -g "$DOCKER_GID" docker-host
    fi
    usermod -aG docker-host runner
  fi

  # Ajustar permissões (garantir que o usuário runner tenha acesso aos arquivos)
  chown -R runner:runner .
  chown -R runner:runner "$WORK_DIR"

  # Reiniciar o script como o usuário runner preservando o ambiente
  exec sudo -u runner -H -E "$BASH_SOURCE" "$@"

else
  echo "Runner is running as runner user"  
  echo ""
fi

# Function to setup new runner
runnerSetup() {

  echo "Runner not found, setting up new runner..."

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
    echo "$TOKEN" > "$WORK_DIR"/.token
    echo "$GITHUB_RUNNER_NAME" > "$WORK_DIR"/.runner-name
  fi

  echo "Configuring runner..."

  ./config.sh \
  --url "${GITHUB_REPO_URL}" \
  --token "${TOKEN}" \
  --name "${GITHUB_RUNNER_NAME}" \
  --labels docker,linux \
  --work "${WORK_DIR}" \
  --unattended \
  --replace

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
    rm -rf "$WORK_DIR"
    echo "Work directory removed successfully."
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
echo "RUN AS: $(whoami)"
echo "-------------------------------------"
echo ""

./run.sh &

wait $!