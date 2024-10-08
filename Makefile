#!/usr/bin/make -f
SRC_DIR	:= $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
TMP_DIR ?= $(SRC_DIR)/tmp
TMP_BIN_DIR ?= $(TMP_DIR)/bin
CACHE_FILE := .promruval_cache.json

PROMRUVAL_BIN := ./promruval

all: clean deps lint build test e2e-test test-release

$(TMP_DIR):
	mkdir -p $(TMP_DIR)

$(TMP_BIN_DIR):
	mkdir -p $(TMP_BIN_DIR)

RELEASE_NOTES ?= $(TMP_DIR)/release_notes
$(RELEASE_NOTES): $(TMP_DIR)
	@echo "Generating release notes to $(RELEASE_NOTES) ..."
	@csplit -q -n1 --suppress-matched -f $(TMP_DIR)/release-notes-part CHANGELOG.md '/## \[\s*v.*\]/' {1}
	@mv $(TMP_DIR)/release-notes-part1 $(RELEASE_NOTES)
	@rm $(TMP_DIR)/release-notes-part*

lint:
	golangci-lint run

lint-fix:
	golangci-lint run --fix

test:
	go test -race ./...

build:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $(PROMRUVAL_BIN)

E2E_TESTS_VALIDATIONS_FILE := examples/validation.yaml
E2E_TESTS_ADDITIONAL_VALIDATIONS_FILE := examples/additional-validation.yaml
E2E_TESTS_RULES_FILES := examples/rules/*.yaml
E2E_TESTS_DOCS_FILE_MD := examples/human_readable.md
E2E_TESTS_DOCS_FILE_HTML := examples/human_readable.html

E2E_TESTS_LOKI_DIR := examples/loki/
E2E_TESTS_MIMIR_DIR := examples/mimir/
E2E_TESTS_THANOS_DIR := examples/thanos/
e2e-test: build
	$(PROMRUVAL_BIN) validate --config-file $(E2E_TESTS_VALIDATIONS_FILE) --config-file $(E2E_TESTS_ADDITIONAL_VALIDATIONS_FILE) $(E2E_TESTS_RULES_FILES)
	$(PROMRUVAL_BIN) validation-docs --config-file $(E2E_TESTS_VALIDATIONS_FILE) --config-file $(E2E_TESTS_ADDITIONAL_VALIDATIONS_FILE) > $(E2E_TESTS_DOCS_FILE_MD)
	$(PROMRUVAL_BIN) validation-docs --config-file $(E2E_TESTS_VALIDATIONS_FILE) --config-file $(E2E_TESTS_ADDITIONAL_VALIDATIONS_FILE) --output=html > $(E2E_TESTS_DOCS_FILE_HTML)

	$(PROMRUVAL_BIN) validate --support-loki --config-file $(E2E_TESTS_LOKI_DIR)/validation.yaml $(E2E_TESTS_LOKI_DIR)/rules.yaml
	$(PROMRUVAL_BIN) validate --support-thanos --config-file $(E2E_TESTS_THANOS_DIR)/validation.yaml $(E2E_TESTS_THANOS_DIR)/rules.yaml
	$(PROMRUVAL_BIN) validate --support-mimir --config-file $(E2E_TESTS_MIMIR_DIR)/validation.yaml $(E2E_TESTS_MIMIR_DIR)/rules.yaml

docker: build
	docker build -t fusakla/promruval .

.PHONY: clean
clean:
	rm -rf dist $(TMP_DIR) $(PROMRUVAL_BIN) $(CACHE_FILE)

.PHONY: deps
deps:
	go mod tidy && go mod verify

test-release:
	goreleaser release --snapshot --clean
