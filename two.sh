#!/usr/bin/env bash
set -e

# Clone target repo
git clone https://fredsuiopaweszxkguqopzx-admin@bitbucket.org/fredsuiopaweszxkguqopzxes/us-ac-v1-007-of-one.git /tmp/repo
cd /tmp/repo

# Extract base image from Dockerfile
if [ ! -f "Dockerfile" ]; then
    echo "ERROR: Dockerfile not found!"
    exit 1
fi

# Find the FROM line and extract the image name
BASE_IMAGE=$(grep -m1 '^FROM' Dockerfile | sed 's/^FROM //' | tr -d '[:space:]')

if [ -z "$BASE_IMAGE" ]; then
    echo "ERROR: Could not find base image in Dockerfile!"
    exit 1
fi

echo "Found base image in Dockerfile: $BASE_IMAGE"

echo "=== Phase 1: Try normal build first ==="
NORMAL_SUCCESS=false

# Try normal build 3 times
for attempt in {1..3}; do
    echo "Normal build attempt $attempt of 3..."
    if docker build -t myimage:latest .; then
        echo "✅ Normal build successful!"
        NORMAL_SUCCESS=true
        break
    else
        if [ $attempt -lt 3 ]; then
            echo "Normal build failed, retrying in 5 seconds..."
            sleep 5
        fi
    fi
done

# If normal build succeeded, skip to run
if [ "$NORMAL_SUCCESS" = true ]; then
    echo "Build successful! Proceeding to run..."
    # Jump to common run section
    run_container
fi

echo -e "\n=== Phase 2: Normal build failed, trying optimized approach ==="

# 1. Increase Docker timeouts
echo "Increasing Docker timeouts..."
sudo tee /etc/docker/daemon.json << EOF
{
  "max-concurrent-downloads": 1,
  "max-download-attempts": 5,
  "dns": ["8.8.8.8", "1.1.1.1"]
}
EOF
sudo systemctl restart docker || sudo service docker restart

# 2. Pre-pull the base image with retry (using extracted image name)
echo "Pre-pulling base image..."
echo "Base image to pull: $BASE_IMAGE"

for attempt in {1..5}; do
    echo "Pull attempt $attempt of 5..."
    if docker pull "$BASE_IMAGE"; then
        echo "Successfully pulled base image"
        break
    else
        if [ $attempt -eq 5 ]; then
            echo "All pull attempts failed. Trying alternative approach..."
            # Continue anyway, build might use cache
        else
            echo "Pull failed, retrying in 15 seconds..."
            sleep 15
        fi
    fi
done

# 3. Build with retry logic
echo "Building Docker image..."
for attempt in {1..3}; do
    echo "Build attempt $attempt of 3..."
    
    # Enable BuildKit for better caching
    DOCKER_BUILDKIT=1 docker build \
        --progress=plain \
        --no-cache \
        -t myimage:latest . && break
        
    if [ $attempt -lt 3 ]; then
        echo "Build failed, cleaning cache and retrying in 10 seconds..."
        docker builder prune -f
        sleep 10
    else
        echo "All build attempts failed!"
        exit 1
    fi
done

echo "Build successful!"

# Common function to run container (used by both phases)
run_container() {
    echo -e "\n=== Running Container ==="
    echo "Running with custom flags:"
    echo "  --shm-size=4g"
    echo "  -e MIN_SLEEP_MINUTES=1"
    echo "  -e MAX_SLEEP_MINUTES=2"
    
    docker run --rm -i \
      --shm-size=4g \
      -e MIN_SLEEP_MINUTES=1 \
      -e MAX_SLEEP_MINUTES=2 \
      myimage:latest
}

# Call the common run function
run_container
