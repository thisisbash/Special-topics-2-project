#!/usr/bin/env bash
set -euo pipefail

# Run on EC2 over SSH from GitHub Actions.
# Required env:
#   DEPLOY_ENV: dev, test, or prod
#   IMAGE_REPOSITORY: Docker Hub image name, e.g. thisisbash/bookshop-st2
#   IMAGE_TAG: tag to deploy

: "${DEPLOY_ENV:?DEPLOY_ENV is required}"
: "${IMAGE_REPOSITORY:?IMAGE_REPOSITORY is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"

case "$DEPLOY_ENV" in
  dev|test|prod) ;;
  *) echo "DEPLOY_ENV must be dev, test, or prod" >&2; exit 1 ;;
esac

APP_ROOT="${APP_ROOT:-/opt/bookshop}"
RELEASE_DIR="$APP_ROOT/$DEPLOY_ENV"
COMPOSE_FILE="$RELEASE_DIR/docker-compose.yml"
ENV_FILE="$RELEASE_DIR/.env"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Missing compose file: $COMPOSE_FILE" >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

export IMAGE_REPOSITORY IMAGE_TAG

printf '%s' "${DOCKERHUB_TOKEN:?DOCKERHUB_TOKEN is required}" \
  | docker login -u "${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME is required}" --password-stdin

docker compose -p "bookshop-$DEPLOY_ENV" -f "$COMPOSE_FILE" pull
docker compose -p "bookshop-$DEPLOY_ENV" -f "$COMPOSE_FILE" up -d --remove-orphans
docker image prune -f

echo "Deployed $IMAGE_REPOSITORY:$IMAGE_TAG to $DEPLOY_ENV"
