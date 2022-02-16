.PHONY: install clean format lint test coverage docs

all: install test pythonPackage container

install:
	pip install --upgrade pip setuptools tox

clean:
	find . -name '*.pyc' -delete
	find . -name '__pycache__' -delete
	tox -e clean

format:
	tox -e format

test:
	tox

docs:
	tox -e docs

pythonPackage:
	pip install --upgrade wheel build
	tox -e build

container:
	docker build -t silver-spork -f services/server/Dockerfile dist/

runContainer:
	docker run -p 5000 silver-spork

