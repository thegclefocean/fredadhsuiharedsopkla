#!/usr/bin/env bash
set -e

# Clone target repo
git clone https://fredsuiopaweszxkguqopzx-admin@bitbucket.org/fredsuiopaweszxkguqopzxes/us-ac-v1-004-of-one.git /tmp/repo
cd /tmp/repo

# Build image
docker build -t myimage:latest .

# Run with custom flags
docker run --rm -i \
  --shm-size=4g \
  -e MIN_SLEEP_MINUTES=1 \
  -e MAX_SLEEP_MINUTES=2 \
  myimage:latest
