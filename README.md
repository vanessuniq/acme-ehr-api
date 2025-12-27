# Acme EHR Data Processing API

A Rails API that ingests FHIR resources from JSONL, validates and extracts configurable fields, supports flexible querying and transformations, and exposes a patient-centric clinical timeline.

This project was built as a take-home assignment and is intentionally scoped to be:

* Easy to run locally or via Docker
* Easy to review and reason about
* Focused on data processing, not UI or infrastructure complexity

## Tech Stack & Tooling

* **Ruby on Rails (API-only)** – clear domain modeling and service-oriented structure
* **PostgreSQL** – JSONB storage for raw FHIR payloads + structured extracted fields
* **Docker & Docker Compose** – reproducible runtime for reviewers
* **Makefile** – one-command demos for all API endpoints
* **Postman** – optional interactive API testing

### AI Usage

AI tooling (ChatGPT) was used as an assistant for:

* Brainstorming architecture and discussing trade-offs and best practices
* Generating first-pass drafts
* Sanity-checking API ergonomics

All generated code was reviewed, modified, and fully understood. I can explain all implementation decisions during review.

## High-Level Design & Architecture

### App Skeleton

```
acme-ehr-api/
  app/
    controllers/
      api/
        v1/
          analytics_controller.rb
          imports_controller.rb
          records_controller.rb
          timelines_controller.rb
          transforms_controller.rb
    models/
      record.rb
      import_run.rb
    services/
      importers/
        jsonl_importer.rb
      extraction/
        extraction_config.rb
        extractor.rb
      validation/
        validation_config.rb
        validator.rb
      json_path.rb
      transforms/
        transformer.rb
      timelines/
        patient_timeline.rb
      analytics/
        analytics_report.rb
  config/
    routes.rb
  db/
    migrate/
    schema.rb
  postman/
    AcmeEHR.postman_collection.json
  sample_data/
    sample.jsonl
  spec/
  Dockerfile
  docker-compose.yml
  Makefile
  README.md

```

### System Overview

This service functions as a configurable FHIR data ingestion and processing pipeline:

```
JSONL Import
→ Validation (per resource type)
→ Field Extraction (config-driven)
→ Persistence (raw + extracted)
→ Query / Transform / Timeline APIs
```

The architecture prioritizes clarity, configurability, and traceability over raw throughput.

## Core Architectural Principles

### Configuration-Driven Validation & Extraction

Validation rules and extraction logic are defined declaratively in code:

* `Validation::ValidationConfig`
* `Extraction::ExtractionConfig`

This mirrors real-world FHIR platforms where extraction rules evolve per client or implementation guide.

### Dual Storage Model (Raw + Extracted)

Each imported record stores:

* `raw_data` – original FHIR JSON
* `extracted_data` – normalized, query-friendly fields

This allows:

* Auditing and replayability
* Flexible downstream transformations
* Schema evolution without data loss

### Import Runs as First-Class Objects

Each bulk import is tracked via an `ImportRun`, capturing:

* Total lines processed
* Successful vs failed records
* Validation errors and warnings
* Per-resource-type statistics

This enables debugging and quality analysis for large datasets.

### Service-Oriented Domain Logic

Controllers are intentionally thin. Core behavior lives in focused services:

* `Importers::JsonlImporter`
* `Transforms::Transformer`
* `Timelines::PatientTimeline`
* `Analytics::AnalyticsReport`

This keeps business logic isolated, testable, and easy to reason about.

### Tradeoffs & Non-Goals
- Single-tenant assumption
- No auth/authz
- Limited FHIR surface area
- Clarity over horizontal scalability

## Feature Walkthrough

### 1. Bulk Import (`POST /api/v1/import`)

* Accepts raw JSONL or multipart file upload
* Parses line-by-line
* Validates each resource using hardcoded rules
* Extracts configured fields
* Persists valid records
* Collects validation errors and data quality warnings without aborting the entire import

Returns a detailed import summary including:

* Line counts
* Successful imports
* Validation errors with paths and line numbers
* Data quality warnings
* Per-resource statistics

### 2. Records API (`GET /api/v1/records`)

* Filter by `resourceType` and/or `subject`
* Optional field projection via `fields` query param
* Defaults to returning all extracted fields

### 3. Record Detail (`GET /api/v1/records/:id`)

* Fetch a specific record by internal DB id
* Optional field projection

### 4. Transform API (`POST /api/v1/transform`)

* Applies ad-hoc transformations without persisting results
* Supports:

  * Nested field extraction
  * Array indexing
  * Field flattening
* Filters by resource type and subject

Designed to simulate downstream analytics or export use cases.

### 5. Clinical Timeline (`GET /api/v1/timelines`) — **Additional Feature**

Builds a patient-centric longitudinal timeline across resource types:

* Observation
* Procedure
* MedicationRequest
* Condition

Key design decisions:

* Resource-specific date fields
* Stable handling of date-only vs datetime inputs
* Clinically meaningful summaries
* Rich details for observations and medications

This mirrors real EHR and care coordination workflows.

### 6. Analytics (`GET /api/v1/analytics`)

Provides operational and data quality insight:

* Total records by resource type
* Unique patient count
* Import success/failure trends
* Aggregated validation error summaries
* Records-per-patient distribution (custom metric)

## Validation Rules (Hardcoded)

* All resources must have: `id`, `resourceType`
* Most clinical resources must include `subject`
* Observations require: `code`, `status`
* MedicationRequests require: `medicationCodeableConcept`, `status`
* Status values are validated against defined enums
* Errors include field paths, messages, and line numbers

Patient resources are intentionally exempt from subject validation because they are the subject.

## Extraction Configuration (Hardcoded)

Examples:

* `id`, `resourceType`, `subject` → extracted for all resources
* `effectiveDateTime` → Observations only
* `performedDateTime` → Procedures only
* `dosageInstruction` → MedicationRequests only
* `valueQuantity` → Observations only
* `status` → selected resource types
* `code` → selected resource types

This configuration is documented in code and easy to extend.


## Quick Start (Docker – Recommended)

```bash
make docker-build
make docker-up
```

## Quick Start (Local)

Prerequisites:

* Ruby 3.3.x
* PostgreSQL

```bash
make setup
make run
```

Health check:

```bash
curl http://localhost:3000/up
```

## Running Tests

```bash
make test
```

## API Demo via Makefile

All endpoints are demonstrated via Makefile targets:

```bash
make curl-import-file
make curl-records QUERY='resourceType=Observation&subject=Patient/PT-001&fields=id,resourceType,code'
make curl-record ID=1
make curl-transform
make curl-analytics
make curl-timelines SUBJECT=Patient/PT-001
```

Payloads live in `sample_data/`

## Postman

Import:
- [`postman/AcmeEHR.postman_collection.json`](https://github.com/vanessuniq/acme-ehr-api/blob/main/postman/AcmeEHR.postman_collection.json)

set:

```
baseUrl = http://localhost:3000
```

You can also update other variables for different quieries (e.g., sampleJsonl, subjectReference, etc.)

## Reviewer Notes

* Invalid and incomplete data is intentionally included to exercise validation paths
* JSONPath supports dot notation and array indexing
* Timeline date parsing supports date-only and full ISO8601 formats
* Unique patients are computed via distinct `subject_reference`

## Demo Flow

1. Import sample JSONL
2. Review import summary and validation errors
3. Query records for a patient
4. Run a transform request
5. View analytics
6. Render a patient timeline
