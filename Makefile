# This Makefile is designed to manage the data pipeline for the taste_dataset using Python, DuckDB, and dbt.
# It provides various targets to automate tasks such as creating a virtual environment,
# installing dependencies, managing the database, running data ingestion, building models,
# running tests, and generating metrics and dashboards.

# Targets:
#   venv           - Create a Python virtual environment in the .venv directory.
#   install        - Install Python dependencies from requirements.txt.
#   clean-db       - Remove the DuckDB warehouse file to reset the database.
#   ingest         - Ingest CSV files into the bronze layer of the data pipeline.
#   bronze         - Alias for the ingest target.
#   silver         - Build silver models using dbt.
#   gold           - Build gold models using dbt.
#   build          - Build both silver and gold models.
#   test-bronze    - Run tests for the bronze layer, including source and custom tests.
#   test-silver    - Run tests for the silver models and their associated tests.
#   test-gold      - Run tests for the gold models and their associated tests.
#   test-custom    - Run custom tests defined in the dbt project.
#   test           - Run all tests (bronze, silver, gold, and custom).
#   dbt-debug      - Run dbt debug to check the dbt configuration and connection.
#   quality_metrics- Runs all tests that measure the defined data quality metrics using a Python script and details on some key results.
#   dashboards     - Run dashboard queries using a Python script.
#   ls             - List dbt resources in the project.
#   all            - Perform a full rebuild of the pipeline, including cleaning the database,
#                    ingesting data, building models, running tests, and generating metrics
#                    and dashboards.

# Variables:
#   SHELL          - Specifies the shell to use for executing commands.
#   ROOT_DIR       - The root directory of the project.
#   VENV_DIR       - The directory for the Python virtual environment.
#   PY             - Path to the Python executable in the virtual environment.
#   PIP            - Path to the pip executable in the virtual environment.
#   DBT            - Path to the dbt executable in the virtual environment.
#   DB_PATH        - Path to the DuckDB database file.
#   DATA_GLOB      - Glob pattern for locating input CSV files.
#   DBT_DIR        - Directory containing the dbt project.
#   DBT_PROFILES_DIR - Directory containing dbt profiles.

# Notes:
# - Ensure Python 3 is installed on your system before running the Makefile.
# - The dbt project directory and profiles directory must be correctly configured.
# - The Makefile assumes the presence of specific Python scripts for data ingestion,
#   quality checks, metrics, and dashboards.



SHELL := /bin/bash

ROOT_DIR := $(CURDIR)
VENV_DIR := $(ROOT_DIR)/.venv
PY := $(VENV_DIR)/bin/python
PIP := $(VENV_DIR)/bin/pip
DBT := $(VENV_DIR)/bin/dbt

DB_PATH := duckdb/taste_warehouse.duckdb
DATA_GLOB := data/*.csv

DBT_DIR := dbt/taste_dataset
DBT_PROFILES_DIR := .profiles

.PHONY: help venv install clean-db ingest bronze silver gold build test \
	test-bronze test-silver test-gold test-custom dbt-debug \
	quality metrics dashboards ls all

help:
	@echo "Targets:"
	@echo "  venv           Create Python virtual environment"
	@echo "  install        Install Python dependencies"
	@echo "  clean-db       Remove DuckDB warehouse file"
	@echo "  ingest         Ingest CSVs into bronze"
	@echo "  silver         Build silver models"
	@echo "  gold           Build gold models"
	@echo "  build          Build silver + gold"
	@echo "  test-bronze    Run bronze tests"
	@echo "  test-silver    Run silver tests"
	@echo "  test-gold      Run gold tests"
	@echo "  test-custom    Run custom tests"
	@echo "  test           Run all tests"
	@echo "  dbt-debug      Run dbt debug"
	@echo "  quality        Alias for metrics"
	@echo "  metrics        Run DQ metrics"
	@echo "  dashboards     Run dashboard queries"
	@echo "  ls             List dbt resources"
	@echo "  all            Full rebuild pipeline"

venv:
	python3 -m venv $(VENV_DIR)

install:
	$(PIP) install -U pip
	$(PIP) install -r requirements.txt

clean-db:
	rm -f $(DB_PATH)

ingest:
	"$(PY)" pipelines/ingest_bronze.py \
		--db "$(DB_PATH)" \
		--input-glob "$(DATA_GLOB)"

bronze: ingest

silver:
	cd "$(DBT_DIR)" && \
	"$(DBT)" run \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select path:models/silver

gold:
	cd "$(DBT_DIR)" && \
	"$(DBT)" run \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select path:models/gold

build: silver gold

test-bronze:
	cd "$(DBT_DIR)" && \
	"$(DBT)" test \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select source:bronze

	cd "$(DBT_DIR)" && \
	"$(DBT)" test \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select path:tests/bronze

test-silver:
	cd "$(DBT_DIR)" && \
	"$(DBT)" test \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select path:models/silver

	cd "$(DBT_DIR)" && \
	"$(DBT)" test \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select path:tests/silver

test-gold:
	cd "$(DBT_DIR)" && \
	"$(DBT)" test \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select path:models/gold

	cd "$(DBT_DIR)" && \
	"$(DBT)" test \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select path:tests/gold

test-custom:
	cd "$(DBT_DIR)" && \
	"$(DBT)" test \
		--profiles-dir "$(DBT_PROFILES_DIR)" \
		--select path:tests

test: test-bronze test-silver test-gold test-custom

dbt-debug:
	cd "$(DBT_DIR)" && \
	"$(DBT)" debug --profiles-dir "$(DBT_PROFILES_DIR)"

metrics:
	"$(PY)" demosql/quality_metrics.py

dashboards:
	"$(PY)" demosql/dashboards.py

ls:
	cd "$(DBT_DIR)" && \
	"$(DBT)" ls --profiles-dir "$(DBT_PROFILES_DIR)"

all: clean-db ingest build test quality_metrics dashboards