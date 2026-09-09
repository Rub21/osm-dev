# osm-dev. `make` lists the targets. Add BRANCH=<branch> to act on a server instance.
.DEFAULT_GOAL := help

ifdef BRANCH
  COMPOSE := bin/deploy.sh $(BRANCH) compose
  SLUG := $(subst _,-,$(BRANCH))
else
  COMPOSE_FILES := -f compose.yaml -f compose.local.yaml
  ifdef PGADMIN
    COMPOSE_FILES += -f compose.pgadmin.yaml
  endif
  COMPOSE := docker compose $(COMPOSE_FILES)
  SLUG := osmdev
endif

.PHONY: help setup up down clean logs shell console psql tokens restore backup proxy-up proxy-down lint

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2}'

setup: ## Create .env from .env.example when missing
	@test -f .env || (cp .env.example .env && echo "created .env from .env.example")
	@mkdir -p .tokens backups

up: setup ## Build and start. Server: make up BRANCH=gps_db REPO=owner/repo [SHA=<commit> | NO_SYNC=1]
ifdef BRANCH
	bin/deploy.sh $(BRANCH) up $(if $(NO_SYNC),--no-sync,$(SHA))
else
	$(COMPOSE) up -d --build
	@echo ""
	@echo "web: http://localhost:3000   first start: make logs"
endif

down: ## Stop, keep the data
	$(COMPOSE) stop

clean: ## Stop and delete the volumes
	$(COMPOSE) down -v

logs: ## Follow the web logs
	$(COMPOSE) logs -f web

shell: ## Bash inside the web container
	$(COMPOSE) exec web bash

console: ## Rails console
	$(COMPOSE) exec web bundle exec rails console

psql: ## psql on the database
	$(COMPOSE) exec db psql -U postgres -d openstreetmap

tokens: ## Print the OAuth tokens as JSON, one per user. REGEN=1 creates new ones
	@$(if $(REGEN),$(COMPOSE) exec -T web bundle exec rails runner /scripts/generate_token.rb >/dev/null,true)
	@cat .tokens/$(SLUG).json

restore: ## Restore a dump: make restore [BACKUP_FILE=/backups/x.dump]
	$(COMPOSE) --profile restore run --rm db_restore

backup: ## Dump the database into backups/<slug>-<date>.dump
	@mkdir -p backups
	@out=backups/$(SLUG)-$$(date +%Y%m%d-%H%M%S).dump; \
	docker exec $(SLUG)-db sh -c \
		'PGPASSWORD="$$POSTGRES_PASSWORD" pg_dump -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -Fc --no-owner --no-acl' \
		> "$$out" \
	&& echo "written $$out ($$(du -h "$$out" | cut -f1))"

proxy-up: ## Server: start the shared Traefik proxy
	docker compose --env-file .env -f proxy/compose.yaml up -d

proxy-down: ## Server: stop the proxy
	docker compose --env-file .env -f proxy/compose.yaml down

lint: ## shellcheck the scripts and validate the compose files
	shellcheck bin/*.sh docker/*.sh
	docker compose -f compose.yaml -f compose.local.yaml -f compose.pgadmin.yaml config -q
	DOMAIN_NAME=lint.example.org docker compose -f compose.yaml -f compose.proxy.yaml -f compose.pgadmin.yaml config -q
