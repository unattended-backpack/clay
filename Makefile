# Configuration is loaded from `.env.maintainer` and can be overridden by
# environment variables.
#
# Usage:
#   make build                    # Build using `.env.maintainer`.
#   BUILD_IMAGE=... make build    # Override specific variables.

# Load configuration from `.env.maintainer` if it exists.
-include .env.maintainer

# Load configuration from `.env` if it exists.
-include .env

# Allow environment variable overrides with defaults.
BUILD_IMAGE ?= unattended/petros:latest
RUNTIME_IMAGE ?= debian:trixie-slim
DOCKER_BUILD_ARGS ?=
DOCKER_RUN_ARGS ?=
CLAY_NAME ?= clay
POTTER_NAME ?= potter
IMAGE_TAG ?= latest
ACT_PULL ?= true

.PHONY: init
init:
	@echo "Initializing configuration files ..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env from .env.example - please review."; \
	else \
		echo ".env already exists."; \
	fi
	@echo "Initialization complete. Review configuration before running."

.PHONY: clean
clean:
	@bash -c 'echo -e "\033[33mWARNING: This will delete build artifacts.\033[0m"; \
	read -p "Are you sure you want to continue? [y/N]: " confirm; \
	if [[ "$$confirm" != "y" && "$$confirm" != "Y" ]]; then \
		echo "Operation cancelled."; \
		exit 1; \
	fi'
	rm -rf out/
	rm -rf target/
	rm -f result result-*

.PHONY: build
build:
	@echo "Building native artifacts ..."
	mkdir -p out
	cargo build --release --bin clay
	cargo build --release --bin potter
	cp ./target/release/clay ./out/clay
	cp ./target/release/potter ./out/potter
	@echo "Build complete."

.PHONY: test
test:
	@echo "Running tests ..."
	cargo test --release
	@echo "... tests completed."

.PHONY: docker-c
docker-c:
	@echo "Building Clay image ..."
	@echo "  Build image:   $(BUILD_IMAGE)"
	@echo "  Runtime image: $(RUNTIME_IMAGE)"
	@echo "  Output tag:    $(CLAY_NAME):$(IMAGE_TAG)"
	@mkdir -p out
	docker build \
		$(DOCKER_BUILD_ARGS) \
		--build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
		--build-arg RUNTIME_IMAGE=$(RUNTIME_IMAGE) \
		-f Dockerfile.clay \
		-t $(CLAY_NAME):$(IMAGE_TAG) \
		.
	@echo "Build complete: $(CLAY_NAME):$(IMAGE_TAG)"

.PHONY: docker-p
docker-p:
	@echo "Building Potter image ..."
	@echo "  Build image:   $(BUILD_IMAGE)"
	@echo "  Runtime image: $(RUNTIME_IMAGE)"
	@echo "  Output tag:    $(POTTER_NAME):$(IMAGE_TAG)"
	@mkdir -p out
	docker build \
		$(DOCKER_BUILD_ARGS) \
		--build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
		--build-arg RUNTIME_IMAGE=$(RUNTIME_IMAGE) \
		-f Dockerfile.potter \
		-t $(POTTER_NAME):$(IMAGE_TAG) \
		.
	@echo "Build complete: $(POTTER_NAME):$(IMAGE_TAG)"

.PHONY: docker
docker:
	$(MAKE) docker-c
	$(MAKE) docker-p

.PHONY: ci
ci:
	@echo "Building Docker images from pre-built binaries (CI mode) ..."
	@if [ ! -f out/clay ] || [ ! -f out/potter ]; then \
		echo "ERROR: Pre-built binaries not found in ./out/" >&2; \
		echo "Run 'make build' first to create the binaries." >&2; \
		exit 1; \
	fi
	@echo "  Build image:   $(BUILD_IMAGE)"
	@echo "  Runtime image: $(RUNTIME_IMAGE)"
	@echo "  Output tag:    $(CLAY_NAME):$(IMAGE_TAG)"
	docker build \
		$(DOCKER_BUILD_ARGS) \
		--build-arg BUILD_TYPE=prebuilt \
		--build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
		--build-arg RUNTIME_IMAGE=$(RUNTIME_IMAGE) \
		-f Dockerfile.clay \
		-t $(CLAY_NAME):$(IMAGE_TAG) \
		.
	@echo "Build complete: $(CLAY_NAME):$(IMAGE_TAG)"
	@echo "  Build image:   $(BUILD_IMAGE)"
	@echo "  Runtime image: $(RUNTIME_IMAGE)"
	@echo "  Output tag:    $(POTTER_NAME):$(IMAGE_TAG)"
	docker build \
		$(DOCKER_BUILD_ARGS) \
		--build-arg BUILD_TYPE=prebuilt \
		--build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
		--build-arg RUNTIME_IMAGE=$(RUNTIME_IMAGE) \
		-f Dockerfile.potter \
		-t $(POTTER_NAME):$(IMAGE_TAG) \
		.
	@echo "Build complete: $(POTTER_NAME):$(IMAGE_TAG)"

.PHONY: run-c
run-c:
	@if [ ! -f .env ]; then \
		echo "ERROR: .env not found" >&2; \
		echo "Run 'make init' to create configuration files." >&2; \
		exit 1; \
	fi
	@echo "Starting Clay container ..."
	docker run --rm -it \
		--name $(CLAY_NAME) \
		$(DOCKER_RUN_ARGS) \
		--env-file .env \
		$(CLAY_NAME):$(IMAGE_TAG)

.PHONY: stop-c
stop-c:
	@echo "Stopping Clay container..."
	docker stop $(CLAY_NAME)
	docker rm $(CLAY_NAME) || true

.PHONY: run-p
run-p:
	@if [ ! -f .env ]; then \
		echo "ERROR: .env not found" >&2; \
		echo "Run 'make init' to create configuration files." >&2; \
		exit 1; \
	fi
	@echo "Starting Potter container ..."
	docker run --rm -it \
		--name $(POTTER_NAME) \
		$(DOCKER_RUN_ARGS) \
		--env-file .env \
		$(POTTER_NAME):$(IMAGE_TAG)

.PHONY: stop-p
stop-p:
	@echo "Stopping Potter container..."
	docker stop $(POTTER_NAME)
	docker rm $(POTTER_NAME) || true

.PHONY: shell-c
shell-c:
	@echo "Opening shell in Clay ..."
	docker run --rm -it \
		--entrypoint /bin/bash \
		$(CLAY_NAME):$(IMAGE_TAG)

.PHONY: shell-p
shell-p:
	@echo "Opening shell in Potter ..."
	docker run --rm -it \
		--entrypoint /bin/bash \
		$(POTTER_NAME):$(IMAGE_TAG)

.PHONY: run
run:
	$(MAKE) build
	$(MAKE) ci
	@echo "Starting Clay and Potter ..."
	docker-compose -f docker-compose.run.yml up \
		--abort-on-container-exit
	@echo "Cleaning up containers ..."
	docker-compose -f docker-compose.run.yml down -v
	@echo "... cleanup complete."

.PHONY: act
act:
	@echo "Running GitHub Actions workflow locally with act ..."
	@if [ ! -d ".act-secrets" ]; then \
		echo "WARNING: .act-secrets/ directory not found" >&2; \
		echo "See docs/WORKFLOW_TESTING.md for setup instructions" >&2; \
	fi
	@echo "Cleaning previous act artifacts to prevent cross-repo contamination ..."
	@rm -rf /tmp/act-artifacts/*
	@echo "Setting up temporary secrets mount ..."
	@sudo mkdir -p /opt/github-runner
	@sudo rm -rf /opt/github-runner/secrets
	@sudo ln -s $(CURDIR)/.act-secrets /opt/github-runner/secrets
	@trap "sudo rm -f /opt/github-runner/secrets" EXIT; \
	DOCKER_HOST="" act push -W .github/workflows/release.yml \
		--container-options "-v /opt/github-runner/secrets:/opt/github-runner/secrets:ro" \
		--artifact-server-path=/tmp/act-artifacts \
		--pull=$(ACT_PULL) \
		$(if $(DOCKER_BUILD_ARGS),--env DOCKER_BUILD_ARGS="$(DOCKER_BUILD_ARGS)")

.PHONY: help
help:
	@echo "Build System"
	@echo ""
	@echo "Targets:"
	@echo "  init            Initialize config from examples."
	@echo "  clean           Clean output directories."
	@echo "  build           Build native binaries."
	@echo "  test            Run all tests for the build."
	@echo "  docker-c        Build just the Clay image."
	@echo "  docker-p        Build just the Potter image."
	@echo "  docker          Build Docker images (compiles inside container)."
	@echo "  ci              Build Docker images from pre-built binaries."
	@echo "  run-c           Run the built Clay image locally."
	@echo "  run-p           Run the built Potter image locally."
	@echo "  run             Run the built Docker images locally."
	@echo "  stop-c          Stop the running Clay container."
	@echo "  stop-p          Stop the running Potter container."
	@echo "  shell-c         Open a shell in the Clay image."
	@echo "  shell-p         Open a shell in the Potter image."
	@echo "  act             Test GitHub Actions release workflow locally."
	@echo "  help            Show this help message."
	@echo ""
	@echo "Configuration:"
	@echo "  Variables are loaded from .env.maintainer."
	@echo "  Override with environment variables:"
	@echo "    BUILD_IMAGE        - Builder image."
	@echo "    RUNTIME_IMAGE      - Runtime base image."
	@echo "    CLAY_NAME          - Clay Docker image name."
	@echo "    POTTER_NAME        - Potter Docker image name."
	@echo "    IMAGE_TAG          - Docker image tag."
	@echo "    DOCKER_BUILD_ARGS  - Additional Docker build flags."
	@echo "    DOCKER_RUN_ARGS    - Additional Docker run flags."
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  BUILD_IMAGE=unattended/petros:latest make build"
	@echo "  IMAGE_TAG=v1.0.0 make build"
	@echo "  DOCKER_BUILD_ARGS='--network host' make build"
	@echo "  DOCKER_RUN_ARGS='--network host' make run-c"

.DEFAULT_GOAL := build
