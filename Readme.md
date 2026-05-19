# Special topics 2 - bookshop project

Book Shop web application for Phase 2 CI/CD pipelines.

## Project By

- Leen Shehadeh - 20220648
- Bushra Abuhantantash - 20220402

## Group size

This is a group of 2, so the test pipeline pushes images to Docker Hub.

## Local setup

```bash
cd book-shop
docker compose up --build
```

Open:

```text
http://localhost:8000
```

## Branch strategy

| Branch | Pipeline philosophy | Deployment port |
| --- | --- | --- |
| `dev` | Artifact-first: build an archive, commit it under `artifacts/`, then build the image from that artifact | `8001` |
| `test` | Image-first: rebuild a fresh artifact from source, build an image, push it to Docker Hub | `8002` |
| `prod` | Promotion-only: pull the existing Docker Hub image tagged by `vars.IMAGE_VERSION`; no build is allowed | `8003` |

## EC2 deployment design

All three branches deploy to the same EC2 instance. They coexist by using:

- separate compose project names: `bookshop-dev`, `bookshop-test`, and `bookshop-prod`
- separate deployment folders under `/opt/bookshop/dev`, `/opt/bookshop/test`, and `/opt/bookshop/prod`
- separate host ports: `8001`, `8002`, and `8003`
- compose-managed networks and Postgres volumes, which are automatically prefixed by the compose project name

The compose files live in:

```text
book-shop/deployment/dev/docker-compose.yml
book-shop/deployment/test/docker-compose.yml
book-shop/deployment/prod/docker-compose.yml
```

Each compose file uses `IMAGE_REPOSITORY` and `IMAGE_TAG`, so GitHub Actions controls which Docker Hub image is deployed without editing the compose file manually.

## EC2 setup

On a fresh Ubuntu EC2 instance, copy or clone this repo and run:

```bash
cd book-shop
chmod +x deployment/ec2-setup.sh
DEPLOY_USER=ubuntu ./deployment/ec2-setup.sh
```

Then log out and back in so the `ubuntu` user receives Docker group access.

Open the EC2 security group inbound rules for:

```text
8001 - dev
8002 - test
8003 - prod
22   - SSH from GitHub Actions
```

Create one `.env` file in each folder on the EC2 instance:

```bash
cp deployment/.env.example /opt/bookshop/dev/.env
cp deployment/.env.example /opt/bookshop/test/.env
cp deployment/.env.example /opt/bookshop/prod/.env
```

Edit each `.env` on EC2 and set real values. Do not commit real secrets.

## GitHub Actions variables and secrets

Configure these under repository Settings -> Secrets and variables -> Actions.

Variables:

| Name | Example | Purpose |
| --- | --- | --- |
| `EC2_HOST` | `ec2-xx-xx-xx.compute.amazonaws.com` | EC2 public DNS or IP |
| `EC2_USER` | `ubuntu` | SSH user |
| `IMAGE_NAME` | `thisisbash/bookshop-st2` | Docker Hub image repository |
| `IMAGE_VERSION` | `test-a1b2c3d` | Production version to promote |

Secrets:

| Name | Purpose |
| --- | --- |
| `EC2_SSH_KEY` | Private key for SSH to the EC2 instance |
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `SECRET_KEY` | Django secret key |
| `POSTGRES_PASSWORD` | Database password |

The app also needs non-sensitive database values such as `POSTGRES_DB`, `POSTGRES_USER`, and `ALLOWED_HOSTS`. These can be stored in the EC2 `.env` files or added as repository variables if the workflow writes `.env` during deployment.

## SSH deployment flow

The deployment script is:

```text
book-shop/deployment/deploy.sh
```

GitHub Actions should copy the correct compose file to EC2 and then run `deploy.sh` over SSH.

Example deploy commands for the `dev` branch:

```bash
mkdir -p /opt/bookshop/dev
DEPLOY_ENV=dev \
IMAGE_REPOSITORY=thisisbash/bookshop-st2 \
IMAGE_TAG=dev \
DOCKERHUB_USERNAME="$DOCKERHUB_USERNAME" \
DOCKERHUB_TOKEN="$DOCKERHUB_TOKEN" \
bash /opt/bookshop/deploy.sh
```

In the actual workflow, use `appleboy/scp-action` to upload:

```text
book-shop/deployment/deploy.sh -> /opt/bookshop/deploy.sh
book-shop/deployment/<env>/docker-compose.yml -> /opt/bookshop/<env>/docker-compose.yml
```

Then use `appleboy/ssh-action` to run:

```bash
chmod +x /opt/bookshop/deploy.sh
DEPLOY_ENV=<dev|test|prod> \
IMAGE_REPOSITORY="${{ vars.IMAGE_NAME }}" \
IMAGE_TAG="<tag-from-this-pipeline-or-vars.IMAGE_VERSION>" \
DOCKERHUB_USERNAME="${{ secrets.DOCKERHUB_USERNAME }}" \
DOCKERHUB_TOKEN="${{ secrets.DOCKERHUB_TOKEN }}" \
/opt/bookshop/deploy.sh
```

For `prod`, the workflow must set:

```bash
IMAGE_TAG="${{ vars.IMAGE_VERSION }}"
```

and must not contain `docker build`, `docker buildx`, artifact packaging, or any new image tagging step.

## Required URLs after deployment

```text
http://<EC2_HOST>:8001  dev
http://<EC2_HOST>:8002  test
http://<EC2_HOST>:8003  prod
```

## Secrets hygiene

The repository includes only `.env.example` files. Real `.env` files, private keys, Docker Hub tokens, and Django/Postgres secrets must stay in GitHub Secrets or on the EC2 instance and must never be committed.
