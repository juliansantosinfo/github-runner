# GitHub Runner Multi-Arch

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Build & Push](https://github.com/juliansantosinfo/github-runner/actions/workflows/deploy.yml/badge.svg)](https://github.com/juliansantosinfo/github-runner/actions/workflows/deploy.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/juliansantosinfo/github-runner.svg)](https://hub.docker.com/r/juliansantosinfo/github-runner)

Runner auto-hospedado do GitHub Actions em um container Docker baseado em **Ubuntu 22.04**, totalmente equipado com **Docker CLI** e **Docker Compose Plugin**.

🚀 Suporte nativo para **multi-plataforma**: `linux/amd64`, `linux/arm64` (Apple Silicon, AWS Graviton) e `linux/arm/v7` (Raspberry Pi 3/4).

---

## 📋 Visão Geral

Este projeto fornece uma solução robusta e automatizada para executar runners do GitHub Actions em containers Docker. Ele gerencia o ciclo de vida completo do runner:
- **Auto-registro:** Registra-se dinamicamente no repositório usando um PAT (Personal Access Token).
- **Auto-remoção:** Desregistra-se de forma segura ao encerrar o container (SIGTERM/SIGINT).
- **Persistência:** Mantém o estado do runner entre reinicializações através de volumes.
- **Docker-in-Docker (Lite):** Permite executar comandos Docker e Docker Compose dentro dos workflows através do compartilhamento do socket.

## 🧰 Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) instalado na máquina host
- [Docker Compose](https://docs.docker.com/compose/) (Plugin v2+)
- Um [Personal Access Token (PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) do GitHub com permissão `repo`

---

## 📁 Estrutura do Projeto

```text
github-runner/
├── .github/workflows/    # Automação de CI/CD (Build & Push Multi-Arch)
├── .vscode/              # Configurações de workspace e tarefas
├── Dockerfile            # Definição multi-estágio da imagem
├── VERSION               # Fonte única de verdade para a versão do runner
├── build.sh              # Script unificado para builds locais e multi-arch
├── docker-compose.yml    # Método de execução recomendado
├── run.sh                # Script auxiliar para execução rápida via Docker CLI
├── start.sh              # Entrypoint (lógica de registro e inicialização)
├── remove.sh             # Script interno para cleanup seguro
└── .env.example          # Modelo de configuração de ambiente
```

---

## ⚙️ Configuração Rápida

### 1. Preparar Ambiente
```bash
cp .env.example .env
```

Edite o `.env` com suas credenciais:
```env
GITHUB_REPO_NAME="meu-repo"
GITHUB_REPO_OWNER="meu-usuario"
GITHUB_PAT="seu_personal_access_token_aqui"
```

> **Atenção:** Nunca suba o arquivo `.env` para o repositório. Ele já está listado no `.gitignore`. Somente o `.env.example` deve ser versionado.

---

## 🚀 Uso

### Opção 1 — Docker Compose (Recomendado)

```bash
# Iniciar o runner em background
docker compose up -d

# Parar o runner
docker compose down
```

### Opção 2 — Script `run.sh`

O script lê as variáveis do arquivo `.env` e, se alguma estiver ausente, solicita interativamente ao usuário.

```bash
./run.sh
```

### Opção 3 — Docker direto

```bash
docker run -d \
  --name github-runner \
  -e GITHUB_PAT=<seu-pat> \
  -e GITHUB_REPO_OWNER=<owner> \
  -e GITHUB_REPO_NAME=<repo> \
  -v /var/run/docker.sock:/var/run/docker.sock \
  juliansantosinfo/github-runner-linux-x64:2.332.0
```

---

## 🔨 Processo de Build

Agora utilizamos um script unificado `build.sh` para simplificar o desenvolvimento e a publicação.

### Setup (Apenas uma vez)
Prepara o ambiente Docker Buildx e emuladores QEMU:
```bash
./build.sh setup
```

### Build Local
Gera a imagem apenas para a arquitetura da sua máquina (rápido):
```bash
./build.sh local
```

### Build & Push Multi-Arch

Gera as imagens para as 3 plataformas suportadas e envia para o Docker Hub:

> Requer o Docker Buildx com suporte a emulação QEMU.

**1. Configurar o ambiente (apenas uma vez):**

```bash
# Instalar emuladores QEMU para cross-arch
docker run --privileged --rm tonistiigi/binfmt --install all

# Criar e ativar um builder dedicado
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap
```

**2. Build e push multi-arch:**

Utilizando o script `build.sh`:

```bash
./build.sh multi
```

Ou diretamente com o Docker Buildx:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  -t juliansantosinfo/github-runner:2.332.0 \
  -t juliansantosinfo/github-runner:latest \
  --push .
```

Alternativamente, use a tarefa **"Build & Push Multi-Arch Image"** disponível no VS Code (`Ctrl+Shift+B`).

### Plataformas suportadas

| Plataforma Docker | Arquitetura | Binário do Runner |
|---|---|---|
| `linux/amd64` | x86_64 | `actions-runner-linux-x64` |
| `linux/arm64` | AArch64 | `actions-runner-linux-arm64` |
| `linux/arm/v7` | ARMv7 | `actions-runner-linux-arm` |

## 🤖 Automação CI/CD

O projeto conta com um workflow de GitHub Actions (`deploy.yml`) que automatiza totalmente o processo:
- **Trigger:** Disparado em `push` na branch `main` ou criação de `tags` (ex: `v2.332.0`).
- **Processo:** Constrói builds paralelos para cada arquitetura, gera artefatos de digest e cria o manifesto multi-arch final no Docker Hub.
- **Cache:** Utiliza cache nativo do GitHub Actions para reduzir o tempo de build.

---

## 🗑️ Remoção do Runner

O runner é removido automaticamente do GitHub quando o container é encerrado (via signal `SIGTERM` ou `SIGINT`). Caso precise remover manualmente ou via `docker exec`:

### Remoção Manual

O script `remove.sh` resolve o token de remoção com a seguinte prioridade:

1. **Variável de ambiente `RUNNER_TOKEN`** — se definida, usada diretamente.
2. **Arquivo `.token`** — gerado automaticamente pelo `start.sh` no registro do runner.
3. Se nenhuma das duas estiver disponível, o script aborta com erro.

Após a remoção bem-sucedida, o arquivo `.token` é apagado automaticamente.

**Forma recomendada** (passando o token via variável de ambiente):

```bash
# 1. Obter o token de remoção via API do GitHub
REMOVE_TOKEN=$(curl -s -X POST \
  -H "Authorization: token <seu-pat>" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/<owner>/<repo>/actions/runners/remove-token \
  | jq -r .token)

# 2. Executar o script de remoção no container
docker exec -e RUNNER_TOKEN="$REMOVE_TOKEN" github-runner ./remove.sh
```

**Forma alternativa** (quando o arquivo `.token` ainda existe no container):

```bash
docker exec github-runner ./remove.sh
```

> **Nota:** O token de remoção é diferente do PAT e possui validade curta. Gere-o imediatamente antes de usar.

---

## 🧩 Labels do Runner

O runner é registrado automaticamente com as labels:

| Label    | Descrição                        |
|----------|----------------------------------|
| `docker` | Indica suporte ao Docker CLI     |
| `linux`  | Sistema operacional base         |

Para usar este runner em um workflow, configure `runs-on`:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, docker]
```

---

## 🐳 Detalhes da Imagem

| Atributo | Valor |
| :--- | :--- |
| **Imagem Base** | `ubuntu:22.04` |
| **Versão do Runner** | `2.332.0` (configurado via `VERSION`) |
| **Plataformas** | `amd64`, `arm64`, `arm/v7` |
| **Docker CLI** | ✅ Incluído |
| **Docker Compose** | ✅ Incluído (Plugin v2+) |
| **Docker Hub** | [juliansantosinfo/github-runner](https://hub.docker.com/r/juliansantosinfo/github-runner) |

---

## 📄 Licença

Este projeto está licenciado sob a [MIT License](./LICENSE).

```
Copyright (c) 2026 Julian Santos
```
