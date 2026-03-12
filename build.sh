#!/bin/bash
set -e

# ─────────────────────────────────────────────
# Configurações
# ─────────────────────────────────────────────
IMAGE_NAME="juliansantosinfo/github-runner"
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
BUILDER_NAME="multiarch"

# Lê a versão do arquivo VERSION (fonte única de verdade)
if [ ! -f VERSION ]; then
  echo "[ERROR] Arquivo VERSION não encontrado na raiz do projeto." >&2
  exit 1
fi
RUNNER_VERSION=$(cat VERSION | tr -d '[:space:]')

# ─────────────────────────────────────────────
# Funções auxiliares
# ─────────────────────────────────────────────
log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

usage() {
  cat <<EOF

Uso: $(basename "$0") [OPÇÃO]

Opções:
  local     Build somente para a arquitetura atual (sem push)
  multi     Build multi-arch (amd64 + arm64 + arm/v7) e faz push
  setup     Configura o Docker Buildx e emuladores QEMU (necessário uma vez antes do 'multi')
  help      Exibe esta mensagem

Exemplos:
  ./build.sh local    # build rápido para teste local
  ./build.sh setup    # prepara o ambiente para builds multi-arch
  ./build.sh multi    # build + push multi-arch para o Docker Hub

EOF
  exit 0
}

# ─────────────────────────────────────────────
# Funções de build
# ─────────────────────────────────────────────
build_local() {
  log "Iniciando build local (arquitetura atual)..."
  log "Imagem: ${IMAGE_NAME}:${RUNNER_VERSION}"

  docker build \
    --build-arg RUNNER_VERSION="${RUNNER_VERSION}" \
    -t "${IMAGE_NAME}:${RUNNER_VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    .

  ok "Build local concluído: ${IMAGE_NAME}:${RUNNER_VERSION}"
}

setup_buildx() {
  log "Configurando ambiente para build multi-arch..."

  log "Instalando emuladores QEMU..."
  docker run --privileged --rm tonistiigi/binfmt --install all
  ok "Emuladores QEMU instalados."

  if docker buildx inspect "${BUILDER_NAME}" > /dev/null 2>&1; then
    warn "Builder '${BUILDER_NAME}' já existe. Reutilizando."
    docker buildx use "${BUILDER_NAME}"
  else
    log "Criando builder '${BUILDER_NAME}'..."
    docker buildx create --name "${BUILDER_NAME}" --use
  fi

  log "Iniciando e inspecionando o builder..."
  docker buildx inspect --bootstrap

  ok "Buildx configurado. Plataformas disponíveis:"
  docker buildx inspect "${BUILDER_NAME}" | grep Platforms
}

build_multi() {
  log "Iniciando build multi-arch..."
  log "Plataformas: ${PLATFORMS}"
  log "Imagem: ${IMAGE_NAME}:${RUNNER_VERSION}"

  if ! docker buildx inspect "${BUILDER_NAME}" > /dev/null 2>&1; then
    warn "Builder '${BUILDER_NAME}' não encontrado. Execute './build.sh setup' primeiro."
    exit 1
  fi

  docker buildx use "${BUILDER_NAME}"

  docker buildx build \
    --platform "${PLATFORMS}" \
    --build-arg RUNNER_VERSION="${RUNNER_VERSION}" \
    -t "${IMAGE_NAME}:${RUNNER_VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    --push \
    .

  ok "Build multi-arch concluído e enviado para o Docker Hub!"
  ok "  → ${IMAGE_NAME}:${RUNNER_VERSION}"
  ok "  → ${IMAGE_NAME}:latest"
}

# ─────────────────────────────────────────────
# Entrada
# ─────────────────────────────────────────────
case "${1:-}" in
  local)  build_local ;;
  setup)  setup_buildx ;;
  multi)  build_multi ;;
  help|--help|-h) usage ;;
  *)
    err "Opção inválida: '${1:-}'"
    usage
    ;;
esac
