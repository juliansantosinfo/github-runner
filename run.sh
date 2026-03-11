#!/bin/bash

source .env

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
    juliansantosinfo/github-runner-linux-x64:2.332.0