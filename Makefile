#!/usr/bin/env make

.PHONY: help setup deploy monitor logs destroy clean

help:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║           ZiVPN - Oracle Free Tier VPN Server             ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@echo "  make setup       - Deploy ZiVPN on Oracle Cloud"
	@echo "  make deploy      - Deploy/restart ZiVPN service"
	@echo "  make monitor     - Open monitoring dashboard"
	@echo "  make logs        - View real-time logs"
	@echo "  make stats       - Get current statistics"
	@echo "  make destroy     - Destroy infrastructure (WARNING!)"
	@echo "  make clean       - Clean local files"
	@echo ""

# Setup Oracle Free Tier
setup:
	@echo "🚀 Setting up ZiVPN on Oracle Cloud Always Free Tier..."
	@bash scripts/zivpn-oracle-free-setup.sh

# Deploy ZiVPN
deploy:
	@echo "📦 Deploying ZiVPN service..."
	@ssh -i ~/.ssh/id_rsa ubuntu@$$(terraform output -raw instance_public_ip 2>/dev/null || echo "[server-ip]") \
		"sudo bash /opt/zivpn/deploy-zivpn.sh"

# Monitor
monitor:
	@SERVER_IP=$$(cd terraform/oracle-free && terraform output -raw instance_public_ip 2>/dev/null); \
	if [ -n "$$SERVER_IP" ]; then \
		echo "Opening ZiVPN Dashboard..."; \
		open "http://$$SERVER_IP:8080" || xdg-open "http://$$SERVER_IP:8080" || echo "Visit: http://$$SERVER_IP:8080"; \
	else \
		echo "❌ Server not deployed yet. Run: make setup"; \
	fi

# Logs
logs:
	@SERVER_IP=$$(cd terraform/oracle-free && terraform output -raw instance_public_ip 2>/dev/null); \
	if [ -n "$$SERVER_IP" ]; then \
		ssh -i ~/.ssh/id_rsa ubuntu@$$SERVER_IP "sudo journalctl -u zivpn -f"; \
	else \
		echo "❌ Server not deployed yet. Run: make setup"; \
	fi

# Stats
stats:
	@SERVER_IP=$$(cd terraform/oracle-free && terraform output -raw instance_public_ip 2>/dev/null); \
	if [ -n "$$SERVER_IP" ]; then \
		curl -s "http://$$SERVER_IP:8080/stats" | jq . || echo "Dashboard not accessible"; \
	else \
		echo "❌ Server not deployed yet. Run: make setup"; \
	fi

# Destroy (with confirmation)
destroy:
	@echo "⚠️  WARNING: This will destroy all ZiVPN infrastructure!"
	@read -p "Are you sure? Type 'yes' to confirm: " CONFIRM; \
	if [ "$$CONFIRM" = "yes" ]; then \
		cd terraform/oracle-free && terraform destroy; \
	else \
		echo "Cancelled."; \
	fi

# Clean
clean:
	@echo "🧹 Cleaning up local files..."
	@rm -rf terraform/oracle-free/.terraform
	@rm -f terraform/oracle-free/*.tfstate*
	@rm -f terraform/oracle-free/*.tfplan
	@echo "✅ Cleaned!"
