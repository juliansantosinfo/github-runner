#!/bin/bash
set -e

if [ -z "$RUNNER_TOKEN" ]; then
  if [ -f .token ]; then
    RUNNER_TOKEN=$(cat .token)
  fi
fi

if [ -z "$RUNNER_TOKEN" ]; then
  echo "RUNNER_TOKEN not set"
  exit 1
fi

echo "Removing runner..."
if ./config.sh remove --token "$RUNNER_TOKEN"; then

  if [ -f .runner ]; then

    GITHUB_RUNNER_NAME=$(jq -r .agentName < .runner)
    if [ -d "_work/$GITHUB_RUNNER_NAME" ]; then
      rm -rf "_work/$GITHUB_RUNNER_NAME"
      echo "Work directory removed successfully."
    fi

  fi

  echo "Runner removed successfully."
fi

rm -f .token
echo "Token file cleaned up."
