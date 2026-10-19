# The GPS tiles prototype. `make` lists the targets. PROXY=1 adds the Traefik overlay on the server.
.DEFAULT_GOAL := help

COMPOSE_FILES := -f compose.yaml
ifdef PROXY
  COMPOSE_FILES += -f compose.proxy.yaml
endif
COMPOSE := docker compose $(COMPOSE_FILES)

.PHONY: help setup up down clean logs psql consumer lint

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-9s\033[0m %s\n", $$1, $$2}'

setup: ## Create .env from .env.example when missing
	@test -f .env || (cp .env.example .env && echo "created .env from .env.example")

up: setup ## Build and start: database, consumer and Martin
	$(COMPOSE) up -d --build
	@echo "tiles: http://127.0.0.1:$${MARTIN_PORT:-3100}/   logs: make logs"

down: ## Stop, keep the data
	$(COMPOSE) down --remove-orphans

clean: ## Stop and delete the database
	$(COMPOSE) down -v --remove-orphans

logs: ## Follow the consumer logs
	$(COMPOSE) logs -f consumer

psql: ## psql on gpstiles
	$(COMPOSE) exec db psql -U postgres -d gpstiles

consumer: ## Run one gpxsync command: make consumer ARGS="update"
	$(COMPOSE) exec consumer gpxsync $(ARGS)

lint: ## shellcheck the scripts and validate the compose files
	shellcheck docker/*.sh
	docker compose -f compose.yaml config -q
	TILES_DOMAIN_NAME=tiles.lint.example.org docker compose -f compose.yaml -f compose.proxy.yaml config -q
