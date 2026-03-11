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
  echo "Runner removed successfully."
fi

rm -f .token
echo "Token file cleaned up."
