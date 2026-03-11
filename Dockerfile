# 1. Usar uma imagem base estável
FROM ubuntu:22.04

# 2. Configurações de ambiente e argumentos para facilitar manutenção
ENV DEBIAN_FRONTEND=noninteractive
ENV GITHUB_PAT=
ENV GITHUB_REPO_OWNER=
ENV GITHUB_REPO_NAME=

ARG RUNNER_VERSION="2.332.0"

WORKDIR /actions-runner

# 3. Instalação de dependências essenciais e repositório Docker em um único passo
# Isso reduz o número de camadas e o tamanho final da imagem
# hadolint ignore=DL3008,DL4006
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg lsb-release jq git build-essential sudo \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# 4. Download e extração do Runner do GitHub
RUN curl -o runner.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && tar xzf ./runner.tar.gz \
    && rm ./runner.tar.gz \
    && ./bin/installdependencies.sh

# 5. Configuração do usuário e permissões (Segurança)
RUN useradd -m runner && \
    groupadd docker || true && \
    usermod -aG sudo,docker runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    chown -R runner:runner /actions-runner

# 6. Preparação do script de entrada
COPY --chown=runner:runner start.sh ./start.sh
COPY --chown=runner:runner remove.sh ./remove.sh
RUN chmod +x ./start.sh ./remove.sh

USER runner

ENTRYPOINT ["./start.sh"]