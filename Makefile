# Makefile for ZA Server VPS

.PHONY: help setup-do setup-oracle destroy deploy backup monitor logs

# Default target
help:
	@echo "ZA Server VPS Commands"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make setup-do         - Deploy on DigitalOcean"
	@echo "  make setup-oracle     - Deploy on Oracle Cloud"
	@echo "  make destroy          - Destroy infrastructure"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make deploy           - Deploy application"
	@echo "  make backup           - Backup data"
	@echo ""
	@echo "Monitoring Commands:"
	@echo "  make monitor          - Setup monitoring"
	@echo "  make logs             - View application logs"
	@echo ""

# Infrastructure setup
setup-do:
	@read -p "Enter DigitalOcean API Token: " TOKEN; \
	bash scripts/digitalocean-setup.sh $$TOKEN

setup-oracle:
	bash scripts/oracle-setup.sh

destroy:
	cd terraform && terraform destroy

# Deployment
deploy:
	@read -p "Enter Server IP: " IP; \
	@read -p "Enter App Name: " APP; \
	bash scripts/deploy.sh $$IP $$APP

backup:
	@read -p "Enter Server IP: " IP; \
	bash scripts/backup.sh $$IP ./backups

# Monitoring
monitor:
	bash scripts/monitoring-setup.sh

logs:
	@read -p "Enter Server IP: " IP; \
	ssh appuser@$$IP "docker-compose logs -f app"

# Local development
dev:
	docker-compose -f config/docker-compose.yml up -d

dev-logs:
	docker-compose -f config/docker-compose.yml logs -f

dev-down:
	docker-compose -f config/docker-compose.yml down
