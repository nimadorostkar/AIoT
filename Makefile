.PHONY: help build up down logs clean restart shell-api shell-web test lint

# Default environment
ENV ?= dev

help: ## Show this help message
	@echo 'Usage: make [target] [ENV=dev|prod]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build all containers
	docker compose build

up: ## Start all services
ifeq ($(ENV),prod)
	docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
else
	docker compose up -d
endif

down: ## Stop all services
	docker compose down

logs: ## Show logs for all services
	docker compose logs -f

clean: ## Remove all containers, networks, and volumes
	docker compose down -v --remove-orphans
	docker system prune -f

restart: down up ## Restart all services

shell-api: ## Access Django shell
	docker compose exec api python manage.py shell

shell-web: ## Access frontend container shell
	docker compose exec web sh

test: ## Run tests
	docker compose exec api python manage.py test

lint: ## Run linting
	docker compose exec api flake8 .
	docker compose exec web npm run lint

migrate: ## Run Django migrations
	docker compose exec api python manage.py migrate

makemigrations: ## Create Django migrations
	docker compose exec api python manage.py makemigrations

superuser: ## Create Django superuser
	docker compose exec api python manage.py ensure_superuser

backup-db: ## Backup database
	docker compose exec db pg_dump -U postgres iot > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore-db: ## Restore database (usage: make restore-db FILE=backup.sql)
	docker compose exec -T db psql -U postgres iot < $(FILE)

status: ## Show status of all services
	docker compose ps

health: ## Run health check
	./docker-healthcheck.sh
