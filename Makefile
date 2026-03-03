SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

PROJECT_NAME ?= qidi-plus4-sidecar
COMPOSE ?= docker compose
BACKUP_DIR ?= ./backups
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
BACKUP_FILE := $(BACKUP_DIR)/$(PROJECT_NAME)-config-$(TIMESTAMP).tar.gz

REQUIRED_FILES := .env \
	go2rtc/go2rtc.yaml \
	mainsail/config.json \
	mainsail/nginx/default.conf \
	obico/moonraker-obico.cfg

.PHONY: help preflight check-tools init setup validate build up up-camera down restart ps logs logs-% pull update backup doctor clean

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*##"; printf "\nQIDI Plus 4 Sidecar - Production Makefile\n\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_.\-%]+:.*##/ { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

preflight: ## Check Linux (ARM64 or x86_64) and minimum 4GB RAM
	@echo "[preflight] Checking host requirements..."
	@test "$(uname -s)" = "Linux" || (echo "ERROR: Linux is required." && exit 1)
	@ARCH=$$(uname -m); \
	if [ "$$ARCH" != "aarch64" ] && [ "$$ARCH" != "arm64" ] && [ "$$ARCH" != "x86_64" ] && [ "$$ARCH" != "amd64" ]; then \
		echo "ERROR: Unsupported architecture: $$ARCH"; \
		echo "Supported: ARM64 (Raspberry Pi 4/5) or x86_64 (Linux development)"; \
		exit 1; \
	fi
	@mem_kb="$$(awk '/MemTotal/ {print $$2}' /proc/meminfo)"; \
	if [ -z "$$mem_kb" ] || [ "$$mem_kb" -lt $$((4 * 1024 * 1024)) ]; then \
		echo "ERROR: At least 4GB RAM is required."; \
		exit 1; \
	fi
	@echo "[preflight] OK"

check-tools: ## Verify required CLI tools are installed
	@echo "[check-tools] Verifying required tools..."
	@command -v docker >/dev/null || (echo "ERROR: docker is not installed" && exit 1)
	@docker compose version >/dev/null || (echo "ERROR: docker compose plugin is not available" && exit 1)
	@command -v curl >/dev/null || (echo "ERROR: curl is not installed" && exit 1)
	@command -v tar >/dev/null || (echo "ERROR: tar is not installed" && exit 1)
	@echo "[check-tools] OK"

init: ## Create local config files from .example templates (if missing)
	@echo "[init] Creating config files when missing..."
	@if [ ! -f .env ]; then \
		if [ -f .env.example ]; then cp .env.example .env; \
		else printf "PRINTER_IP=192.168.68.35\nHOST_IP=192.168.68.26\nTZ=UTC\nOBICO_AUTH_TOKEN=CHANGE_ME\nOBICO_SECRET_KEY=CHANGE_ME\n" > .env; fi; \
	fi
	@[ -f go2rtc/go2rtc.yaml ] || cp go2rtc/go2rtc.yaml.example go2rtc/go2rtc.yaml
	@[ -f mainsail/config.json ] || cp mainsail/config.json.example mainsail/config.json
	@[ -f mainsail/nginx/default.conf ] || cp mainsail/nginx/default.conf.example mainsail/nginx/default.conf
	@[ -f obico/moonraker-obico.cfg ] || cp obico/moonraker-obico.cfg.example obico/moonraker-obico.cfg
	@echo "[init] Done"

setup: preflight check-tools init ## Run bootstrap script (repairs file issues + checks devices)
	@echo "[setup] Running setup.sh..."
	@chmod +x setup.sh
	@./setup.sh

validate: check-tools ## Validate Docker Compose configuration and required config files
	@echo "[validate] Validating required files..."
	@for f in $(REQUIRED_FILES); do \
		[ -f "$$f" ] || (echo "ERROR: Missing $$f" && exit 1); \
	done
	@echo "[validate] Validating Compose..."
	@$(COMPOSE) config > /tmp/$(PROJECT_NAME)-compose-resolved.yml
	@echo "[validate] OK"

build: validate ## Build images
	@$(COMPOSE) build

up: validate ## Start core services (without camera profile)
	@echo "[usb-camera] Checking WSL2 USB camera auto-attach..."
	@bash ./scripts/auto-attach-usb-camera.sh
	@echo "[camera] Detecting camera source..."
	@bash ./scripts/auto-camera-device.sh
	@$(COMPOSE) up -d

up-camera: validate ## Start services including go2rtc camera profile
	@echo "[camera] Detecting camera device..."
	@bash ./scripts/auto-camera-device.sh
	@$(COMPOSE) --profile camera up -d

down: ## Stop and remove stack
	@$(COMPOSE) down

restart: ## Restart running services
	@$(COMPOSE) restart

ps: ## Show service status
	@$(COMPOSE) ps

logs: ## Follow logs for all services
	@$(COMPOSE) logs -f --tail=150

logs-%: ## Follow logs for one service (example: make logs-mainsail)
	@$(COMPOSE) logs -f --tail=150 $*

pull: ## Pull latest images
	@$(COMPOSE) pull

update: pull up ## Pull and restart services with latest images
	@echo "[update] Completed"

backup: ## Backup runtime config files
	@mkdir -p "$(BACKUP_DIR)"
	@tar -czf "$(BACKUP_FILE)" \
		.env \
		go2rtc/go2rtc.yaml \
		mainsail/config.json \
		mainsail/nginx/default.conf \
		obico/moonraker-obico.cfg
	@echo "[backup] Created $(BACKUP_FILE)"

doctor: validate ps ## Run quick diagnostics (no platform check - works on any arch)
	@echo "[doctor] Checking endpoints..."
	@curl -fsS http://localhost:8080 >/dev/null && echo "[doctor] Mainsail OK" || echo "[doctor] Mainsail unreachable"
	@curl -fsS http://localhost:9101/metrics >/dev/null && echo "[doctor] Exporter OK" || echo "[doctor] Exporter unreachable"

clean: ## Remove dangling Docker images/containers/networks (safe cleanup)
	@docker image prune -f
	@docker container prune -f
	@docker network prune -f
	@echo "[clean] Docker cleanup done"
