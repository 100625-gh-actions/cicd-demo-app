# ============================================================
# Makefile - Development & Operations Shortcuts
# ============================================================
# This Makefile provides convenient shortcuts for common
# development tasks. Instead of remembering long commands,
# developers can simply run:
#
#   make install    - Set up the project
#   make test       - Run tests
#   make lint       - Check code quality
#   make run        - Start the app locally
#
# Run `make help` to see all available targets.
# ============================================================

# Declare all targets as "phony" (not actual files).
# Without this, if a file named "test" existed, `make test`
# would think it's already up-to-date and skip execution.
.PHONY: help install test test-cov lint run docker-build docker-run docker-stop clean

# Default target -- runs when you type just `make`
help: ## Show all available targets with descriptions
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ============================================================
# Development Targets
# ============================================================

install: ## Install all dependencies (production + dev/test)
	pip install -r app/requirements.txt -r app/requirements-dev.txt

test: ## Run unit tests with verbose output
	pytest tests/ -v

test-cov: ## Run tests with coverage report (terminal + HTML)
	pytest tests/ -v --cov=app --cov-report=term-missing --cov-report=html

lint: ## Run flake8 linter on app and test code
	flake8 app/ tests/

run: ## Run Flask development server on port 5000
	flask --app app.app run --host=0.0.0.0 --port=5000

# ============================================================
# Docker Targets
# ============================================================

docker-build: ## Build the Docker image with version info
	docker build -t cicd-demo-app .

docker-run: ## Run the app in a Docker container (detached, port 5000)
	docker run -d -p 5000:5000 --name cicd-demo cicd-demo-app

docker-stop: ## Stop and remove the Docker container
	docker stop cicd-demo && docker rm cicd-demo

# ============================================================
# Cleanup Targets
# ============================================================

clean: ## Remove all generated files and caches
	rm -rf __pycache__ .pytest_cache htmlcov .coverage
	rm -rf build dist *.egg-info
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type f -name "*.pyo" -delete 2>/dev/null || true
