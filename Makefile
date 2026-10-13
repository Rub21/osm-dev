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
  ifdef OSMREP
    COMPOSE_FILES += -f compose.osmrep.yaml
  endif
  COMPOSE := docker compose $(COMPOSE_FILES)
  SLUG := osmdev
endif

.PHONY: help setup up down clean logs shell console psql test tokens app apps restore backup proxy-up proxy-down lint osmrep

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

down: ## Stop, keep the data. Also removes pgAdmin when it was started with PGADMIN=1
	$(COMPOSE) down --remove-orphans

clean: ## Stop and delete the volumes, pgAdmin and osmrep included
	$(COMPOSE) down -v --remove-orphans
	docker volume rm -f $(SLUG)_pgadmin-data $(SLUG)_osmrep-bundle $(SLUG)_replication-data >/dev/null

logs: ## Follow the web logs
	$(COMPOSE) logs -f web

shell: ## Bash inside the web container
	$(COMPOSE) exec web bash

console: ## Rails console
	$(COMPOSE) exec web bundle exec rails console

psql: ## psql on the database
	$(COMPOSE) exec db psql -U postgres -d openstreetmap

test: ## Run the Rails tests on openstreetmap_test: make test [ARGS=test/jobs]
	$(COMPOSE) exec -e RAILS_ENV=test web sh -c 'unset DATABASE_URL; bundle exec rails db:create db:test:prepare >/dev/null 2>&1; bundle exec rails test $(ARGS)'

osmrep: ## Run one osmrep command in the replication container: make osmrep OSMREP=1 ARGS="gpx dump -o /data/gpx-dump.osm.gz"
	$(COMPOSE) exec osmrep bundle exec bin/osmrep $(ARGS)

tokens: ## Print the OAuth tokens as JSON, one per user. REGEN=1 creates new ones
	@$(if $(REGEN),$(COMPOSE) exec -T web bundle exec rails runner /scripts/generate_token.rb >/dev/null,true)
	@cat .tokens/$(SLUG).json

app: ## Create or replace one OAuth app: make app NAME=josm [SCOPES="..."] [REDIRECT=...]
	@test -n "$(NAME)" || (echo "usage: make app NAME=<name> [SCOPES=\"read_prefs write_gpx\"] [REDIRECT=<uri>] [BRANCH=<branch>]"; exit 1)
	@$(COMPOSE) exec -T -e APP_NAME="$(NAME)" -e SCOPES="$(SCOPES)" -e REDIRECT_URI="$(REDIRECT)" web bundle exec rails runner /scripts/oauth-apps/create_app.rb

apps: ## Print the OAuth apps of the instance as JSON, with client id and secret (scripts/oauth-apps/apps.json says which ones exist)
	@$(COMPOSE) exec -T web bundle exec rails runner /scripts/oauth-apps/create_app.rb >/dev/null
	@cat .tokens/$(SLUG)-apps.json

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
	docker compose -f compose.yaml -f compose.local.yaml -f compose.pgadmin.yaml -f compose.osmrep.yaml config -q
	DOMAIN_NAME=lint.example.org PGADMIN_DOMAIN_NAME=pgadmin.lint.example.org REPLICATION_DOMAIN_NAME=replication.lint.example.org PGADMIN_PASSWORD=lint docker compose -f compose.yaml -f compose.proxy.yaml -f compose.pgadmin.yaml -f compose.pgadmin.proxy.yaml -f compose.osmrep.yaml -f compose.osmrep.proxy.yaml config -q
