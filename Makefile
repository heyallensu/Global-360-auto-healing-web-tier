SHELL := /bin/bash
.DEFAULT_GOAL := check

ENV ?= staging
TF_DIR := environments/$(ENV)
BACKEND_CONFIG := backend.hcl
BACKEND_PATH := $(TF_DIR)/$(BACKEND_CONFIG)
VAR_FILE := terraform.tfvars
VAR_PATH := $(TF_DIR)/$(VAR_FILE)
PLAN_FILE := $(ENV).tfplan
PLAN_PATH := $(TF_DIR)/$(PLAN_FILE)
TFLINT_CONFIG := $(CURDIR)/.tflint.hcl
IMAGE ?= global-360-web:test

.PHONY: check-env fmt fmt-check init init-ci lock validate lint scan validate-env quality-global check plan apply deploy destroy output docker-build sonar

check-env:
	@test "$(ENV)" = "staging" -o "$(ENV)" = "production" || (echo "ENV must be staging or production" && exit 1)

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

lint:
	tflint --config=$(TFLINT_CONFIG) --init
	tflint --config=$(TFLINT_CONFIG) --recursive

scan:
	trivy config --exit-code 1 --severity HIGH,CRITICAL --skip-version-check .

validate-env: fmt-check init-ci validate

quality-global: lint scan

check: validate-env quality-global

plan: init
	@test -f $(VAR_PATH) || (echo "Missing $(VAR_PATH)" && exit 1)
	@! grep -q 'REPLACE_WITH' $(VAR_PATH) || (echo "Replace placeholder values in $(VAR_PATH)" && exit 1)
	terraform -chdir=$(TF_DIR) plan -input=false -lock-timeout=5m -var-file=$(VAR_FILE) -out=$(PLAN_FILE)

apply: init
	@test -f $(PLAN_PATH) || (echo "Missing $(PLAN_PATH); run make plan ENV=$(ENV) first" && exit 1)
	terraform -chdir=$(TF_DIR) show $(PLAN_FILE)
	terraform -chdir=$(TF_DIR) apply -lock-timeout=5m $(PLAN_FILE)
	rm -f $(PLAN_PATH)

deploy: plan
	$(MAKE) apply ENV=$(ENV)

destroy: init
	@test -f $(VAR_PATH) || (echo "Missing $(VAR_PATH)" && exit 1)
	terraform -chdir=$(TF_DIR) destroy -lock-timeout=5m -var-file=$(VAR_FILE)

output: init
	terraform -chdir=$(TF_DIR) output

docker-build:
	docker build -t $(IMAGE) docker

sonar:
	docker run --rm -e SONAR_HOST_URL -e SONAR_TOKEN -v "$(CURDIR):/usr/src" sonarsource/sonar-scanner-cli:11.1@sha256:0b90dedf01ef875d69a5a151f73d72b8288a319b39cdfd2ee32a729027a00785
