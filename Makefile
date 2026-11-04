SHELL         := bash
.SHELLFLAGS   := -euo pipefail -c
.DEFAULT_GOAL := help

# Optional local AWS credentials (gitignored), loaded into make's environment.
# Accepts `export KEY=value` or `KEY=value` lines.
ifneq (,$(wildcard .env.aws))
  $(foreach line,$(shell sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Z_][A-Z0-9_]*)=["'\'']?([^"'\'']*)["'\'']?[[:space:]]*$$/\2=\3/p' .env.aws),$(eval export $(line)))
endif

ENV          ?= dev
AWS_REGION   ?= eu-west-1
# owner/repo, taken from the git remote. CI roles trust GitHub tokens from this repo only.
REPO         ?= $(shell git remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$$##')
TF_DIR       := infra/terraform/envs/$(ENV)
TF           := terraform -chdir=$(TF_DIR)
TF_VARS      := -var region=$(AWS_REGION) -var github_repository=$(REPO)
TAG          ?= try-$(shell date +%s)
TMPDIR       ?= /tmp
TASKDEF_TMP  := $(TMPDIR)/lexicheck-taskdef.json

export AWS_REGION

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# ------------------------------------------------------------------ local dev
.PHONY: install
install: ## Install API and web dependencies
	cd api && uv sync
	cd web && npm ci

.PHONY: api
api: ## Run the API with hot reload on :8080
	cd api && uv run uvicorn lexicheck.main:app --reload --port 8080

.PHONY: web
web: ## Run the web dev server on :5173
	cd web && npm run dev

.PHONY: dev
dev: ## Run API (:8080) and web (:5173) together with hot reload; Ctrl+C stops both
	trap 'kill 0' EXIT; \
	(cd api && uv run uvicorn lexicheck.main:app --reload --port 8080) & \
	(cd web && npm run dev) & \
	wait

.PHONY: up
up: ## Start the full local stack (http://localhost:8081)
	docker compose up -d --build --wait

.PHONY: up-obs
up-obs: ## Local stack plus Prometheus (:9090) and Grafana (:3000)
	docker compose --profile observability up -d --build --wait

.PHONY: down
down: ## Stop the local stack and remove its data
	docker compose --profile observability down -v

.PHONY: logs
logs: ## Tail local stack logs
	docker compose logs -f

# ------------------------------------------------------------------ quality
.PHONY: lint
lint: ## Lint and format-check everything
	cd api && uv run ruff check . && uv run ruff format --check .
	cd web && npm run check
	terraform fmt -check -recursive infra/terraform

.PHONY: fmt
fmt: ## Auto-format Python and Terraform
	cd api && uv run ruff format . && uv run ruff check --fix .
	terraform fmt -recursive infra/terraform

.PHONY: test
test: ## Run API tests
	cd api && uv run pytest -q

.PHONY: build
build: ## Build the web bundle and the API image
	cd web && npm run build
	docker build -t lexicheck-api:local api

.PHONY: smoke
smoke: ## Hit the running local stack end to end
	curl -fsS localhost:8081/api/readyz && echo
	curl -fsS -X POST localhost:8081/api/v1/check -H 'content-type: application/json' \
	  -d '{"text":"Ths is a tset"}' | jq -e '.issues | length == 2'

.PHONY: tf-validate
tf-validate: ## terraform validate every environment (no AWS needed)
	for env in infra/terraform/envs/*/; do \
	  terraform -chdir="$$env" init -backend=false -input=false >/dev/null; \
	  terraform -chdir="$$env" validate; \
	done

.PHONY: check
check: lint test tf-validate ## Everything CI runs locally, except scans

TRIVY = docker run --rm -v $(CURDIR):/src -v /var/run/docker.sock:/var/run/docker.sock \
        -v $(HOME)/.cache/trivy:/root/.cache -w /src aquasec/trivy:latest

.PHONY: scan
scan: ## Trivy: Terraform misconfigs, dependency CVEs + secrets, and the API image
	$(TRIVY) config --severity HIGH,CRITICAL --ignorefile .trivyignore --exit-code 1 infra/terraform
	$(TRIVY) fs --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 \
	  --skip-dirs web/node_modules,api/.venv --skip-files .env.aws .
	docker build -q -t lexicheck-api:scan api >/dev/null
	$(TRIVY) image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 lexicheck-api:scan

# ------------------------------------------------------------------ AWS
# State lives in S3 (encrypted, versioned, native lockfile). `make aws-bootstrap`
# creates the bucket once per account and region.
# Usage: make aws-bootstrap   then   make aws-up   then   make aws-down

ACCOUNT_ID    = $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
STATE_BUCKET ?= lexicheck-tfstate-$(ACCOUNT_ID)-$(AWS_REGION)

.PHONY: aws-whoami
aws-whoami: ## Show which AWS account and identity will be used
	aws sts get-caller-identity --query '[Account,Arn]' --output text

.PHONY: aws-bootstrap
aws-bootstrap: ## Create the encrypted, versioned S3 bucket for Terraform state (idempotent)
	@test -n "$(ACCOUNT_ID)" || { echo "No AWS credentials. Set AWS_PROFILE first." >&2; exit 1; }
	if aws s3api head-bucket --bucket $(STATE_BUCKET) 2>/dev/null; then \
	  echo "state bucket $(STATE_BUCKET) already exists"; \
	else \
	  aws s3api create-bucket --bucket $(STATE_BUCKET) \
	    $$( [ "$(AWS_REGION)" = us-east-1 ] || echo --create-bucket-configuration LocationConstraint=$(AWS_REGION) ) >/dev/null; \
	  echo "created $(STATE_BUCKET)"; \
	fi
	aws s3api put-public-access-block --bucket $(STATE_BUCKET) --public-access-block-configuration \
	  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
	aws s3api put-bucket-versioning --bucket $(STATE_BUCKET) --versioning-configuration Status=Enabled
	aws s3api put-bucket-encryption --bucket $(STATE_BUCKET) --server-side-encryption-configuration \
	  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
	aws s3api put-bucket-policy --bucket $(STATE_BUCKET) --policy \
	  '{"Version":"2012-10-17","Statement":[{"Sid":"TLSOnly","Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["arn:aws:s3:::$(STATE_BUCKET)","arn:aws:s3:::$(STATE_BUCKET)/*"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}'

.PHONY: aws-account
aws-account: aws-oidc ## Account-wide setup: $$20 budget alerts + GitHub CI roles (EMAIL=you@x.com, LIMIT=20)
	@test -n "$(ACCOUNT_ID)" || { echo "No AWS credentials. Set AWS_PROFILE first." >&2; exit 1; }
	@test -n "$(EMAIL)" || { echo "Usage: make aws-account EMAIL=you@example.com [LIMIT=20]" >&2; exit 1; }
	terraform -chdir=infra/terraform/envs/account init -input=false -reconfigure \
	  -backend-config=bucket=$(STATE_BUCKET) -backend-config=region=$(AWS_REGION) >/dev/null
	terraform -chdir=infra/terraform/envs/account apply -input=false -auto-approve \
	  -var region=$(AWS_REGION) -var 'budget_emails=["$(EMAIL)"]' -var monthly_budget=$(or $(LIMIT),20) \
	  -var github_repository=$(REPO) -var state_bucket=$(STATE_BUCKET)

.PHONY: gh-setup
gh-setup: aws-init ## Connect GitHub Actions to AWS: create environments and set variables with gh
	@command -v gh >/dev/null || { echo "Install the GitHub CLI (gh) first." >&2; exit 1; }
	@echo "Configuring $(REPO)"
	out=$$($(TF) output -json deploy); acct=$$(terraform -chdir=infra/terraform/envs/account output -json ci); \
	v() { jq -r ".$$1" <<<"$$out"; }; \
	gh api -X PUT repos/$(REPO)/environments/dev >/dev/null; \
	gh api -X PUT repos/$(REPO)/environments/infra --input - >/dev/null <<<'{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'; \
	gh api -X POST repos/$(REPO)/environments/infra/deployment-branch-policies -f name=main -f type=branch >/dev/null 2>&1 || true; \
	set_env() { gh variable set "$$1" --env dev --repo $(REPO) --body "$$2" >/dev/null && echo "  dev: $$1"; }; \
	set_env DEPLOY_ROLE_ARN    "$$(v role_arn)"; \
	set_env ECR_REPOSITORY_URL "$$(v ecr_repository_url)"; \
	set_env ECS_CLUSTER        "$$(v cluster)"; \
	set_env ECS_SERVICE        "$$(v service)"; \
	set_env TASK_FAMILY        "$$(v task_family)"; \
	set_env SITE_BUCKET        "$$(v site_bucket)"; \
	set_env DISTRIBUTION_ID    "$$(v distribution_id)"; \
	set_env APP_URL            "$$(v url)"; \
	set_repo() { gh variable set "$$1" --repo $(REPO) --body "$$2" >/dev/null && echo "  repo: $$1"; }; \
	set_repo AWS_REGION        "$(AWS_REGION)"; \
	set_repo TF_STATE_BUCKET   "$(STATE_BUCKET)"; \
	set_repo TF_PLAN_ROLE_ARN  "$$(jq -r .plan_role_arn <<<"$$acct")"; \
	set_repo TF_APPLY_ROLE_ARN "$$(jq -r .apply_role_arn <<<"$$acct")"; \
	set_repo AWS_DEPLOY_ENABLED true
	@echo "Done. Push to main (or run the Release workflow) to deploy."

.PHONY: gh-disconnect
gh-disconnect: ## Stop GitHub from deploying (run before make aws-down)
	gh variable set AWS_DEPLOY_ENABLED --repo $(REPO) --body false

.PHONY: aws-init
aws-init:
	@test -n "$(ACCOUNT_ID)" || { echo "No AWS credentials. Set AWS_PROFILE first." >&2; exit 1; }
	$(TF) init -input=false -reconfigure \
	  -backend-config=bucket=$(STATE_BUCKET) -backend-config=region=$(AWS_REGION) >/dev/null

.PHONY: aws-oidc
aws-oidc: ## Create the GitHub OIDC provider if the account lacks one
	aws iam list-open-id-connect-providers --output text | grep -q token.actions.githubusercontent.com \
	  || aws iam create-open-id-connect-provider \
	       --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com

.PHONY: aws-plan
aws-plan: aws-init ## terraform plan for ENV (default dev)
	$(TF) plan -input=false $(TF_VARS)

.PHONY: aws-apply
aws-apply: aws-init aws-oidc ## terraform apply for ENV (about 15 min)
	$(TF) apply -input=false -auto-approve $(TF_VARS)

.PHONY: aws-push
aws-push: ## Build the ARM64 API image, push it and roll the ECS service
	ecr=$$($(TF) output -json deploy | jq -r .ecr_repository_url); \
	cluster=$$($(TF) output -json deploy | jq -r .cluster); \
	service=$$($(TF) output -json deploy | jq -r .service); \
	family=$$($(TF) output -json deploy | jq -r .task_family); \
	aws ecr get-login-password | docker login -u AWS --password-stdin "$${ecr%%/*}" >/dev/null; \
	docker buildx build --platform linux/arm64 -t "$$ecr:$(TAG)" --push api; \
	aws ecs describe-task-definition --task-definition "$$family" --query taskDefinition --output json \
	  | jq --arg img "$$ecr:$(TAG)" '.containerDefinitions[0].image=$$img | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy)' \
	  > $(TASKDEF_TMP); \
	td=$$(aws ecs register-task-definition --cli-input-json file://$(TASKDEF_TMP) \
	  --query taskDefinition.taskDefinitionArn --output text); \
	aws ecs update-service --cluster "$$cluster" --service "$$service" --task-definition "$$td" >/dev/null; \
	echo "waiting for $$service to stabilise..."; \
	aws ecs wait services-stable --cluster "$$cluster" --services "$$service"

.PHONY: aws-site
aws-site: ## Build the frontend and publish it to S3 + CloudFront
	cd web && npm ci --silent && npm run build --silent
	bucket=$$($(TF) output -json deploy | jq -r .site_bucket); \
	dist=$$($(TF) output -json deploy | jq -r .distribution_id); \
	aws s3 sync web/dist/assets "s3://$$bucket/assets" --cache-control "public,max-age=31536000,immutable"; \
	aws s3 sync web/dist "s3://$$bucket" --exclude "assets/*" --exclude index.html \
	  --cache-control "public,max-age=86400"; \
	aws s3 cp web/dist/index.html "s3://$$bucket/index.html" --cache-control no-cache; \
	aws cloudfront create-invalidation --distribution-id "$$dist" --paths '/*' >/dev/null

.PHONY: aws-smoke
aws-smoke: ## Smoke test the deployed environment through CloudFront
	url=$$($(TF) output -raw url); \
	for _ in $$(seq 1 30); do curl -fsS "$$url/api/readyz" && break; sleep 10; done; echo; \
	curl -fsS -X POST "$$url/api/v1/check" -H 'content-type: application/json' \
	  -d '{"text":"Ths is a tset"}' | jq .; \
	echo "open $$url"

.PHONY: aws-up
aws-up: aws-apply aws-push aws-site aws-smoke ## Full deploy: infra, image, site, smoke test

.PHONY: aws-down
aws-down: aws-init ## Destroy everything aws-up created
	repo=$$($(TF) output -json deploy 2>/dev/null | jq -r '.ecr_repository_url // empty' | cut -d/ -f2); \
	if [ -n "$$repo" ]; then \
	  ids=$$(aws ecr list-images --repository-name "$$repo" --query imageIds --output json); \
	  [ "$$ids" = "[]" ] || aws ecr batch-delete-image --repository-name "$$repo" --image-ids "$$ids" >/dev/null; \
	fi
	$(TF) destroy -input=false -auto-approve $(TF_VARS)
	@echo "Destroyed $(ENV). Kept: state bucket $(STATE_BUCKET) (cents/month) and the GitHub OIDC provider (free)."
	@echo "Run 'make aws-delete-state' to remove the state bucket too."

.PHONY: aws-delete-state
aws-delete-state: ## Delete the Terraform state bucket and every version in it (irreversible)
	@read -p "Delete s3://$(STATE_BUCKET) and all state history? Type the bucket name: " ans; \
	  [ "$$ans" = "$(STATE_BUCKET)" ] || { echo aborted; exit 1; }
	aws s3api list-object-versions --bucket $(STATE_BUCKET) --output json \
	  | jq '{Objects: [(.Versions // [])[], (.DeleteMarkers // [])[] | {Key, VersionId}], Quiet: true}' \
	  > $(TMPDIR)/lexicheck-state-objects.json
	jq -e '.Objects | length > 0' $(TMPDIR)/lexicheck-state-objects.json >/dev/null \
	  && aws s3api delete-objects --bucket $(STATE_BUCKET) --delete file://$(TMPDIR)/lexicheck-state-objects.json >/dev/null || true
	aws s3api delete-bucket --bucket $(STATE_BUCKET)
