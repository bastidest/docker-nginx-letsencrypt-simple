#!/bin/bash
set -euo pipefail

IMAGE="library/nginx"
PAST_DAYS=90

function getToken() {
    curl -s --user "$DOCKER_USERNAME:$DOCKER_PASSWORD" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull" | jq -r '.token'
}

# query all existing image tags
TAGS=$(curl -s "https://registry.hub.docker.com/v1/repositories/$IMAGE/tags" | jq -r '.[].name' | grep -v alpine)
TOKEN=$(getToken)

NEW_TAGS=()

for tag in $TAGS ; do
    timestamp=$(curl -s "https://registry.hub.docker.com/v2/$IMAGE/manifests/$tag" -H "Authorization:Bearer $TOKEN" | jq -r '.history[0].v1Compatibility' | jq -r '.created')
    ts_seconds=$(date -u -d "$timestamp" +"%s")
    now_seconds=$(date -u +"%s")
    diff=$((now_seconds - ts_seconds))

    if (( diff < ((PAST_DAYS * 24 * 60 * 60)) )) ; then
	NEW_TAGS+=("$tag")
	echo "added $tag ($timestamp)"
    else
	echo "did not add $tag ($timestamp)"
    fi
done

set +e
for tag in "${NEW_TAGS[@]}" ; do
    echo "NGINX_BASE_VERSION=$tag" > .env
    docker-compose build
    docker-compose push
done
set -e
