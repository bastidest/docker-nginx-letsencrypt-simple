#!/bin/bash
set -euo pipefail

IMAGE="library/nginx"

function getToken() {
    curl --no-progress-meter --user "$DOCKER_USERNAME:$DOCKER_PASSWORD" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull" | jq -r '.token'
}

# query all existing image tags
TAGS=$(curl --no-progress-meter "https://registry.hub.docker.com/v1/repositories/$IMAGE/tags" | jq -r '.[].name')
TOKEN=$(getToken)

NEW_TAGS=()

for tag in $TAGS ; do
    timestamp=$(curl --no-progress-meter "https://registry.hub.docker.com/v2/$IMAGE/manifests/$tag" -H "Authorization:Bearer $TOKEN" | jq -r '.history[0].v1Compatibility' | jq -r '.created')
    ts_seconds=$(date -u -d "$timestamp" +"%s")
    now_seconds=$(date -u +"%s")
    diff=$((now_seconds - ts_seconds))

    if [[ $diff < $((7 * 24 * 60 * 60)) ]] ; then
	NEW_TAGS+=("$tag")
	echo "added $tag"
	break
    fi
done

for tag in "${NEW_TAGS[@]}" ; do
    echo "NGINX_BASE_VERSION=$tag" > .env
    docker-compose build
    docker-compose push
done
