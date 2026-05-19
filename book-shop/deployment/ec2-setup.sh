#!/usr/bin/env bash
set -euo pipefail

# Run once on the EC2 instance before the GitHub Actions deploy jobs.

APP_ROOT="${APP_ROOT:-/opt/bookshop}"
DEPLOY_USER="${DEPLOY_USER:-ubuntu}"

sudo apt-get update
sudo apt-get install -y ca-certificates curl git

if ! command -v docker >/dev/null 2>&1; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

sudo usermod -aG docker "$DEPLOY_USER"

sudo mkdir -p "$APP_ROOT"/{dev,test,prod}
sudo chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_ROOT"

cat <<MSG
EC2 setup complete.

Deployment root: $APP_ROOT

Log out and back in so the $DEPLOY_USER user receives Docker group access.
Open inbound security group ports 8001, 8002, and 8003 for dev, test, and prod.
MSG
