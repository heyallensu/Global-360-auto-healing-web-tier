SHELL := /bin/bash
.DEFAULT_GOAL := check
.NOTPARALLEL:

ENV ?= staging
TF_DIR := environments/$(ENV)
BACKEND_CONFIG := backend.hcl
BACKEND_PATH := $(TF_DIR)/$(BACKEND_CONFIG)
VAR_FILE := terraform.tfvars
VAR_PATH := $(TF_DIR)/$(VAR_FILE)
GIT_SHA := $(shell git rev-parse --short=12 HEAD)
PLAN_NAME := $(ENV)-$(GIT_SHA).tfplan
PLAN_PATH := $(TF_DIR)/$(PLAN_NAME)
DESTROY_PLAN_NAME := destroy-$(ENV)-$(GIT_SHA).tfplan
DESTROY_PLAN_PATH := $(TF_DIR)/$(DESTROY_PLAN_NAME)
TFLINT_CONFIG := $(CURDIR)/.tflint.hcl
IMAGE ?= global-360-web:test

.PHONY: check-env check-clean check-local-inputs check-workspace fmt fmt-check init init-ci lock validate lint scan validate-env quality-global check plan show-plan apply destroy-plan show-destroy destroy-apply output docker-build sonar bootstrap-init bootstrap-plan

check-env:
	@test "$(ENV)" = "staging" -o "$(ENV)" = "production" || (echo "ENV must be staging or production" && exit 1)

check-clean:
	@test -z "$$(git status --porcelain)" || (echo "Tracked or untracked project files exist; review and commit or remove them before plan/apply" && exit 1)

check-local-inputs: check-env
	@unexpected="$$(find $(TF_DIR) modules -type f \( -name '*.auto.tfvars' -o -name '*.auto.tfvars.json' -o -name 'terraform.tfvars.json' -o -name 'override.tf' -o -name 'override.tf.json' -o -name '*_override.tf' -o -name '*_override.tf.json' \) -print)"; test -z "$$unexpected" || (echo "Unsupported automatic or override inputs:"; echo "$$unexpected"; exit 1)
	@hidden_env="$$(env | sed -n -e 's/^\(TF_VAR_[^=]*\)=.*/\1/p' -e 's/^\(TF_CLI_ARGS[^=]*\)=.*/\1/p' -e 's/^\(TF_WORKSPACE\)=.*/\1/p')"; test -z "$$hidden_env" || (echo "Unsupported hidden Terraform environment inputs:"; echo "$$hidden_env"; exit 1)

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

init: check-env
	@test -f $(BACKEND_PATH) || (echo "Missing $(BACKEND_PATH)" && exit 1)
	terraform -chdir=$(TF_DIR) init -reconfigure -backend-config=$(BACKEND_CONFIG) -input=false

init-ci: check-env
	terraform -chdir=$(TF_DIR) init -backend=false -input=false

lock: init-ci
	terraform -chdir=$(TF_DIR) providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64

validate: check-env
	terraform -chdir=$(TF_DIR) validate

lint: check-env
	tflint --config=$(TFLINT_CONFIG) --init
	tflint --config=$(TFLINT_CONFIG) --recursive

scan:
	trivy config --exit-code 1 --severity HIGH,CRITICAL --skip-version-check .

validate-env: fmt-check init-ci validate

quality-global: lint scan

check: validate-env quality-global

check-workspace: init
	@test "$$(terraform -chdir=$(TF_DIR) workspace show)" = "default" || (echo "Only the default Terraform workspace is supported" && exit 1)

plan: check-clean check-local-inputs check-workspace
	@test -f $(VAR_PATH) || (echo "Missing $(VAR_PATH)" && exit 1)
	@! grep -q 'REPLACE_WITH' $(VAR_PATH) || (echo "Replace placeholder values in $(VAR_PATH)" && exit 1)
	@umask 077; terraform -chdir=$(TF_DIR) plan -input=false -lock-timeout=5m -var-file=$(VAR_FILE) -out=$(PLAN_NAME)
	@umask 077; printf '%s\n' "$$(git rev-parse HEAD)" > $(PLAN_PATH).commit
	@umask 077; shasum -a 256 $(VAR_PATH) $(BACKEND_PATH) > $(PLAN_PATH).inputs.sha256

show-plan: check-clean check-local-inputs check-workspace
	@test -f $(PLAN_PATH) || (echo "Missing $(PLAN_PATH)" && exit 1)
	terraform -chdir=$(TF_DIR) show $(PLAN_NAME)

apply: check-clean check-local-inputs check-workspace
	@test -f $(PLAN_PATH) -a -f $(PLAN_PATH).commit -a -f $(PLAN_PATH).inputs.sha256 || (echo "Missing reviewed plan or metadata" && exit 1)
	@test "$$(cat $(PLAN_PATH).commit)" = "$$(git rev-parse HEAD)" || (echo "Plan was created from a different commit" && exit 1)
	shasum -a 256 -c $(PLAN_PATH).inputs.sha256
	terraform -chdir=$(TF_DIR) show $(PLAN_NAME)
	terraform -chdir=$(TF_DIR) apply -lock-timeout=5m $(PLAN_NAME)
	rm -f $(PLAN_PATH) $(PLAN_PATH).commit $(PLAN_PATH).inputs.sha256

destroy-plan: check-clean check-local-inputs check-workspace
	@test -f $(VAR_PATH) || (echo "Missing $(VAR_PATH)" && exit 1)
	@! grep -q 'REPLACE_WITH' $(VAR_PATH) || (echo "Replace placeholder values in $(VAR_PATH)" && exit 1)
	@echo "Planning destruction for root module: $(TF_DIR)"
	@umask 077; terraform -chdir=$(TF_DIR) plan -destroy -input=false -lock-timeout=5m -var-file=$(VAR_FILE) -out=$(DESTROY_PLAN_NAME)
	@umask 077; printf '%s\n' "$$(git rev-parse HEAD)" > $(DESTROY_PLAN_PATH).commit
	@umask 077; shasum -a 256 $(VAR_PATH) $(BACKEND_PATH) > $(DESTROY_PLAN_PATH).inputs.sha256

show-destroy: check-clean check-local-inputs check-workspace
	@test -f $(DESTROY_PLAN_PATH) || (echo "Missing $(DESTROY_PLAN_PATH)" && exit 1)
	terraform -chdir=$(TF_DIR) show $(DESTROY_PLAN_NAME)

destroy-apply: check-clean check-local-inputs check-workspace
	@test -f $(DESTROY_PLAN_PATH) -a -f $(DESTROY_PLAN_PATH).commit -a -f $(DESTROY_PLAN_PATH).inputs.sha256 || (echo "Missing reviewed destroy plan or metadata" && exit 1)
	@test "$$(cat $(DESTROY_PLAN_PATH).commit)" = "$$(git rev-parse HEAD)" || (echo "Destroy plan was created from a different commit" && exit 1)
	shasum -a 256 -c $(DESTROY_PLAN_PATH).inputs.sha256
	terraform -chdir=$(TF_DIR) show $(DESTROY_PLAN_NAME)
	terraform -chdir=$(TF_DIR) apply -lock-timeout=5m $(DESTROY_PLAN_NAME)
	rm -f $(DESTROY_PLAN_PATH) $(DESTROY_PLAN_PATH).commit $(DESTROY_PLAN_PATH).inputs.sha256

output: check-workspace
	terraform -chdir=$(TF_DIR) output

docker-build:
	docker build -t $(IMAGE) docker

sonar:
	docker run --rm -e SONAR_HOST_URL -e SONAR_TOKEN -v "$(CURDIR):/usr/src" sonarsource/sonar-scanner-cli:11.1

bootstrap-init:
	terraform -chdir=bootstrap init -input=false

bootstrap-plan: bootstrap-init
	terraform -chdir=bootstrap plan -input=false -lock-timeout=5m -out=bootstrap.tfplan
