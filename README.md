# GitHub Runner Linux x64

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Runner auto-hospedado do GitHub Actions em um container Docker baseado em Ubuntu 22.04, com suporte ao Docker CLI e Docker Compose Plugin.

---

## 📋 Visão Geral

Este projeto empacota o [GitHub Actions Runner](https://github.com/actions/runner) em uma imagem Docker. Ao iniciar o container, ele se registra automaticamente em um repositório do GitHub usando um PAT (Personal Access Token) e, ao ser encerrado, remove o registro do runner de forma segura.

## 🧰 Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) instalado na máquina host
- [Docker Compose](https://docs.docker.com/compose/) (Plugin v2+)
- Um [Personal Access Token (PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) do GitHub com permissão `repo`

---

## 📁 Estrutura do Projeto

```
github-runner/
├── .env                  # Variáveis de ambiente (não versionar)
├── .env.example          # Modelo de variáveis de ambiente
├── .gitignore
├── .vscode/
│   ├── extensions.json   # Extensões recomendadas para VS Code
│   └── tasks.json        # Tarefas de build e execução para VS Code
├── Dockerfile            # Definição da imagem Docker
├── docker-compose.yml    # Orquestração do container
├── LICENSE               # Licença MIT
├── run.sh                # Script para executar o container via `docker run`
├── start.sh              # Entrypoint: registra e inicializa o runner
└── remove.sh             # Script para remover o runner manualmente
```

---

## ⚙️ Configuração

### 1. Variáveis de Ambiente

Copie o arquivo de exemplo e preencha com os seus valores:

```bash
cp .env.example .env
```

Edite o `.env` gerado:

```env
GITHUB_REPO_NAME=<nome-do-repositório>
GITHUB_REPO_OWNER=<usuário-ou-organização>
GITHUB_PAT=<seu-personal-access-token>
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

## 🔨 Build da Imagem

Para construir a imagem localmente a partir do `Dockerfile`:

```bash
docker build -t juliansantosinfo/github-runner-linux-x64:2.332.0 .
```

Ou utilize a tarefa do VS Code: **`Terminal > Run Build Task`** (`Ctrl+Shift+B`).

---

## 🗑️ Remoção do Runner

O runner é removido automaticamente do GitHub quando o container é encerrado (via signal `SIGTERM` ou `SIGINT`).

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

## 🐳 Imagem Docker

| Propriedade   | Valor                                           |
|---------------|-------------------------------------------------|
| Base Image    | `ubuntu:22.04`                                  |
| Runner Version| `2.332.0`                                       |
| Arquitetura   | `linux/amd64`                                   |
| Docker Hub    | `juliansantosinfo/github-runner-linux-x64`       |

---

## 📄 Licença

Este projeto está licenciado sob a [MIT License](./LICENSE).

```
Copyright (c) 2026 Julian Santos
```
