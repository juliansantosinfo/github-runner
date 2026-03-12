# GitHub Actions Runner

Self-hosted GitHub Actions Runner packaged as a multi-arch Docker image based on **Ubuntu 22.04**, with built-in **Docker CLI** and **Docker Compose Plugin** support.

---

## Supported Platforms

| Platform | Architecture |
|---|---|
| `linux/amd64` | x86_64 |
| `linux/arm64` | AArch64 (Raspberry Pi 4, AWS Graviton) |
| `linux/arm/v7` | ARMv7 (Raspberry Pi 3) |

---

## Quick Start

### Docker Compose (recommended)

Create a `docker-compose.yml`:

```yaml
services:
  github-runner:
    image: juliansantosinfo/github-runner:latest
    environment:
      - GITHUB_PAT=<your-personal-access-token>
      - GITHUB_REPO_OWNER=<owner>
      - GITHUB_REPO_NAME=<repository>
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - github-runner-data:/actions-runner
    restart: always

volumes:
  github-runner-data:
```

Then run:

```bash
docker compose up -d
```

### Docker CLI

```bash
docker run -d \
  --name github-runner \
  -e GITHUB_PAT=<your-personal-access-token> \
  -e GITHUB_REPO_OWNER=<owner> \
  -e GITHUB_REPO_NAME=<repository> \
  -v /var/run/docker.sock:/var/run/docker.sock \
  juliansantosinfo/github-runner:latest
```

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `GITHUB_PAT` | ✅ | Personal Access Token with `repo` scope |
| `GITHUB_REPO_OWNER` | ✅ | GitHub username or organization |
| `GITHUB_REPO_NAME` | ✅ | Target repository name |

> Generate a PAT at: **GitHub → Settings → Developer settings → Personal access tokens**

---

## How It Works

1. On startup, the container calls the GitHub API to obtain a **registration token** and registers itself as a self-hosted runner.
2. The runner is labeled with `docker` and `linux` automatically.
3. On container shutdown (`SIGTERM` / `SIGINT`), the runner **unregisters itself** from GitHub automatically.
4. Runner state is persisted in the `/actions-runner` volume so the container can restart without re-registering.

---

## Using the Runner in a Workflow

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, docker]
    steps:
      - uses: actions/checkout@v4
      - run: docker compose version
```

---

## Runner Labels

| Label | Description |
|---|---|
| `self-hosted` | Default label for all self-hosted runners |
| `linux` | Operating system |
| `docker` | Docker CLI and Compose available |

---

## Image Details

| Property | Value |
|---|---|
| Base Image | `ubuntu:22.04` |
| Runner Version | `2.332.0` |
| Docker CLI | ✅ Included |
| Docker Compose | ✅ Included (plugin) |
| Runs as | Non-root user (`runner`) |

---

## Source Code

[github.com/juliansantosinfo/github-runner](https://github.com/juliansantosinfo/github-runner)

---

## License

[MIT License](https://github.com/juliansantosinfo/github-runner/blob/main/LICENSE) © Julian Santos
