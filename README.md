# 12 -- Full CI/CD Lifecycle Showcase

A complete CI/CD pipeline demonstration using GitHub Actions, Docker, and AWS.
This showcase simulates a real-world software delivery workflow -- from feature
development on a branch all the way through production deployment and rollback.

---

## Architecture

```
Developer --> Feature Branch --> Pull Request --> CI Pipeline --> Code Review
                                                    |
                                  Merge to main --> CD Staging --> Deploy to EC2 (staging)
                                                    |
                                  GitHub Release --> CD Production --> Deploy to EC2 (production)
                                                    |
                                  Manual trigger --> Rollback --> Deploy previous version
                                                    |
                                  Cron schedule --> Health Checks --> Auto-create Issue on failure
```

---

## Workflow Overview

| Workflow | File | Trigger | Purpose |
|---|---|---|---|
| CI Pipeline | `ci.yml` | `pull_request` | Lint, test, build Docker image, post PR comment |
| PR Review | `pr-review.yml` | `pull_request_review` | Auto-label PRs (approved / changes-requested) |
| CD Staging | `cd-staging.yml` | `push` to `main` | Build + push to GHCR, deploy to staging EC2 |
| CD Production | `cd-production.yml` | `release` published | Deploy versioned image to production with approval |
| Rollback | `rollback.yml` | `workflow_dispatch` | Rollback to a specific version on staging or production |
| Health Check | `scheduled-health.yml` | `schedule` (cron) | Periodic health checks, auto-create issues on failure |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Python 3.12, Flask |
| Containerization | Docker (multi-stage build), GHCR |
| Infrastructure | Terraform, AWS EC2 (free tier) |
| CI/CD | GitHub Actions |
| Testing | pytest, flake8 |
| Production Server | Gunicorn |

---

## Project Structure

```
12-full-cicd-lifecycle-brainstormed/
|-- .github/
|   |-- workflows/
|       |-- ci.yml                  # CI pipeline (lint, test, build)
|       |-- pr-review.yml           # Auto-label on PR reviews
|       |-- cd-staging.yml          # Deploy to staging on merge
|       |-- cd-production.yml       # Deploy to production on release
|       |-- rollback.yml            # Manual rollback workflow
|       |-- scheduled-health.yml    # Periodic health checks
|-- app/
|   |-- app.py                      # Flask application
|   |-- templates/
|   |   |-- index.html              # Dashboard UI template
|   |-- requirements.txt            # Production dependencies
|   |-- requirements-dev.txt        # Dev/test dependencies
|-- tests/
|   |-- conftest.py                 # Shared test fixtures
|   |-- test_app.py                 # App route tests
|   |-- test_items.py               # Items API tests
|-- terraform/
|   |-- main.tf                     # EC2 infrastructure definition
|   |-- variables.tf                # Terraform input variables
|   |-- outputs.tf                  # Terraform outputs
|   |-- terraform.tfvars.example    # Example variable values
|   |-- user_data_staging.sh        # EC2 bootstrap script (staging)
|   |-- user_data_production.sh     # EC2 bootstrap script (production)
|-- Dockerfile                      # Multi-stage Docker build
|-- .dockerignore                   # Files excluded from Docker context
|-- Makefile                        # Development shortcuts
|-- .flake8                         # Linter configuration
|-- .gitignore                      # Git ignore rules
|-- README.md                       # This file
```

---

## Prerequisites

- GitHub account with access to the `100625-gh-actions` org
- AWS account (free tier is sufficient)
- Docker installed locally
- Python 3.10+
- Terraform 1.5+

---

## Quick Start (Local Development)

```bash
# Install dependencies
make install

# Run linter
make lint

# Run unit tests
make test

# Run tests with coverage report
make test-cov

# Start Flask development server on port 5000
make run

# Build Docker image
make docker-build

# Run Docker container (detached, port 5000)
make docker-run

# Stop and remove Docker container
make docker-stop

# Clean generated files and caches
make clean
```

After running `make run` or `make docker-run`, open http://localhost:5000 to see the dashboard.

---

## API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/` | Dashboard UI (HTML) |
| GET | `/api/health` | Health check (status, version, environment) |
| GET | `/api/version` | Version and build info |
| GET | `/api/items` | List all demo items |
| GET | `/api/items/<id>` | Get a single item by ID |

---

## Demo Story

The live demo is split into two acts that walk through the entire lifecycle.

### Act 1 -- Ship a Feature

1. Create a feature branch and add a greeting endpoint
2. Open a Pull Request -- CI pipeline runs automatically
3. Review the PR -- labels are applied by the review workflow
4. Merge to `main` -- CD staging deploys to the staging EC2 instance
5. Create a GitHub Release -- CD production deploys to production (with approval)
6. Verify both environments via the health check endpoints

### Act 2 -- Break It, Roll It Back, Fix It

1. Introduce a bug through a new PR (e.g., a broken endpoint)
2. CI passes but the bug slips through to staging after merge
3. Health check detects the failure and creates a GitHub Issue
4. Trigger the rollback workflow to restore the previous version
5. Fix the bug properly on a new branch and repeat the pipeline

---

## Related Showcases

This showcase brings together concepts from the earlier showcases in the series:

| # | Showcase | Topic |
|---|---|---|
| 01 | Hello Actions | First workflow, YAML basics |
| 02 | Triggers | Event types and filters |
| 03 | Environment | Env vars, secrets, contexts |
| 04 | Matrix | Matrix builds |
| 05 | Artifacts | Upload/download artifacts |
| 06 | Caching | Dependency caching |
| 07 | Docker | Docker build and push |
| 08 | Deployment | Environment deployments |
| 09 | Reusable Workflows | Composite and reusable workflows |
| 10 | Security | Permissions and OIDC |
| 11 | Monitoring | Scheduled jobs and notifications |
| **12** | **Full Lifecycle** | **Everything combined (this showcase)** |

---

## Links

- Step-by-step walkthrough: [WALKTHROUGH.md](WALKTHROUGH.md)
