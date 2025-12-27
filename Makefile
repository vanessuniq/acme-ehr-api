JQ := $(shell command -v jq 2>/dev/null)

# Use as: ... | $(PRETTY)
ifeq ($(strip $(JQ)),)
PRETTY := cat
else
PRETTY := jq .
endif



APP_NAME ?= acme_ehr

# API (local)
API_BASE ?= http://localhost:3000/api/v1
SAMPLE_JSONL ?= sample_data/sample.jsonl

.PHONY: help setup run test \
        db-reset db-migrate \
        docker-build docker-up docker-down docker-reset docker-test docker-logs \
        curl-import-raw curl-import-file curl-records curl-record curl-transform curl-analytics curl-timelines

help:
	@echo ""
	@echo "Targets:"
	@echo "  make setup              Install deps + db:prepare + clear logs/tmp (via bin/setup)"
	@echo "  make run                Start dev server (bin/dev)"
	@echo "  make test               Run RSpec"
	@echo "  make db-migrate         Run migrations"
	@echo "  make db-reset           Drop + create + migrate db"
	@echo ""
	@echo "Docker (compose):"
	@echo "  make docker-build       Build images"
	@echo "  make docker-up          Start app + db (entrypoint runs db:prepare)"
	@echo "  make docker-down        Stop app + db"
	@echo "  make docker-reset       Down (volumes) + up"
	@echo "  make docker-test        Run tests in Docker"
	@echo "  make docker-logs        Tail logs"
	@echo ""
	@echo "API demos (curl):"
	@echo "  make curl-import-raw    POST /import using raw JSONL body"
	@echo "  make curl-import-file   POST /import using multipart file upload"
	@echo "  make curl-records       GET /records (optionally set QUERY=...)"
	@echo "  make curl-record        GET /records/:id (set ID=... DB id)"
	@echo "  make curl-transform     POST /transform"
	@echo "  make curl-analytics     GET /analytics"
	@echo "  make curl-timelines     GET /timelines (set SUBJECT=Patient/PT-001)"
	@echo ""

setup:
	bin/setup --skip-server

run:
	bin/dev

test:
	bundle exec rspec

db-migrate:
	bin/rails db:migrate

db-reset:
	bin/rails db:drop db:create db:migrate

# --------------------
# Docker (compose)
# --------------------
docker-build:
	docker compose build

docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-reset:
	docker compose down -v
	docker compose up -d

docker-logs:
	docker compose logs -f --tail=200

# --------------------
# API demos (curl)
# --------------------
curl-import-raw:
	@echo "POST $(API_BASE)/import (raw JSONL)"
	@curl -sS -X POST "$(API_BASE)/import" \
		-H "Content-Type: text/plain" \
		--data-binary "@$(SAMPLE_JSONL)" | $(PRETTY)

curl-import-file:
	@echo "POST $(API_BASE)/import (multipart file upload)"
	@curl -sS -X POST "$(API_BASE)/import" \
		-F "file=@$(SAMPLE_JSONL)" | $(PRETTY)

# Optional: provide QUERY='resourceType=Observation&subject=Patient/PT-001&fields=id,resourceType,code'
curl-records:
	@echo "GET $(API_BASE)/records?$(QUERY)"
	@curl -sS "$(API_BASE)/records?$(QUERY)" | $(PRETTY)

# Requires a DB id, not the FHIR resource_id
curl-record:
	@if [ -z "$(ID)" ]; then echo "Set ID=<record_db_id>"; exit 1; fi
	@echo "GET $(API_BASE)/records/$(ID)?fields=$(FIELDS)"
	@curl -sS "$(API_BASE)/records/$(ID)?fields=$(FIELDS)" | $(PRETTY)

curl-transform:
	@echo "POST $(API_BASE)/transform"
	@curl -sS -X POST "$(API_BASE)/transform" \
		-H "Content-Type: application/json" \
		-d @sample_data/transform_observation.json | $(PRETTY)

curl-analytics:
	@echo "GET $(API_BASE)/analytics"
	@curl -sS "$(API_BASE)/analytics" | $(PRETTY)

# Optional: RESOURCE_TYPES=Observation,MedicationRequest FROM=2025-01-01 TO=2025-12-31 LIMIT=50
curl-timelines:
	@if [ -z "$(SUBJECT)" ]; then echo "Set SUBJECT=Patient/PT-001"; exit 1; fi
	@echo "GET $(API_BASE)/timelines?subject=$(SUBJECT)&resourceTypes=$(RESOURCE_TYPES)&from=$(FROM)&to=$(TO)&limit=$(LIMIT)"
	@curl -sS "$(API_BASE)/timelines?subject=$(SUBJECT)&resourceTypes=$(RESOURCE_TYPES)&from=$(FROM)&to=$(TO)&limit=$(LIMIT)" | $(PRETTY)
