PYTHON ?= python3
POETRY ?= poetry
PACKAGE = krr_operator

.PHONY: install run lint test fmt clean

install:
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -e .[dev]

run:
	KOPF_RUN=1 $(PYTHON) -m $(PACKAGE)

lint:
	ruff check src tests

test:
	pytest

fmt:
	ruff check --select I --fix src tests

clean:
	rm -rf .ruff_cache .pytest_cache build dist *.egg-info
