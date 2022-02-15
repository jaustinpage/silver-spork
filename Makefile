.PHONY: install clean format lint test coverage docs

all: venv install format test lint coverage docs release

rebuild_venv:
	rm -rf .venv
	python3 -m venv .venv

venv:
ifndef VIRTUAL_ENV
	$(error Not in virtual environment. run `source .venv/bin/activate`. if this fails, run `make rebuild_venv; source .venv/bin/activate`)
endif

install:
	pip install --upgrade pip setuptools
	pip install -e .[testing]

clean:
	find . -name '*.pyc' -delete
	find . -name '__pycache__' -delete
	tox -e clean

format:
	isort src tests setup.py
	black src/ tests/ --exclude version.py
	mdformat --wrap 88 docs
	mdformat --wrap 88 src
	mdformat --wrap 88 tests
	sort -o whitelist.txt whitelist.txt || sort /o whitelist.txt whitelist.txt

lint:
	flake8 --ignore= src/
	flake8 --ignore=ABS101,ANN,DAR,D103,E501,S101 tests/

test:
	tox

docs:
	tox -e docs

release:
	pip install --upgrade wheel build
	tox -e build
