.PHONY: clean-pyc clean-build docs clean
define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help:
	@echo "clean - remove all build, test, coverage and Python artifacts"
	@echo "clean-build - remove build artifacts"
	@echo "clean-pyc - remove Python file artifacts"
	@echo "clean-test - remove test and coverage artifacts"
	@echo "lint - check style with flake8"
	@echo "test - run tests quickly with the default Python"
	@echo "test-all - run tests on every Python version with tox"
	@echo "coverage - check code coverage quickly with the default Python"
	@echo "docs - generate Sphinx HTML documentation, including API docs"
	@echo "release - package and upload a release"
	@echo "dist - package"
	@echo "install - install the package to the active Python's site-packages"

clean: clean-build clean-pyc clean-test

clean-build:
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	rm -Rf py_mini_racer/*.so
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc:
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-test:
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/

lint:
	flake8 py_mini_racer tests

test:
	python setup.py test

test-all:
	tox

coverage:
	coverage run --source py_mini_racer setup.py test
	coverage report -m
	coverage html
	$(BROWSER) htmlcov/index.html

docs:
	rm -f docs/py_mini_racer.rst
	rm -f docs/modules.rst
	sphinx-apidoc -o docs/ py_mini_racer
	$(MAKE) -C docs clean
	$(MAKE) -C docs html
	$(BROWSER) docs/_build/html/index.html

servedocs: docs
	watchmedo shell-command -p '*.rst' -c '$(MAKE) -C docs html' -R -D .

release: clean
	python setup.py sdist upload
	python setup.py bdist_wheel upload

dist: clean
	python setup.py sdist
	python setup.py bdist_wheel
	ls -l dist

docker-build: clean
	# Sdist
	python setup.py sdist

	# Generate host wheels
	python setup.py bdist_wheel
	python3 setup.py bdist_wheel

	# Generate linux wheels
	docker-compose build
	# Clean the existing volume
	docker volume rm py_mini_racer_build_volume || true
	docker volume create --name py_mini_racer_build_volume

	# Run the generated build image
	docker run --rm=true -v py_mini_racer_build_volume:/artifact py_mini_racer.build

	# Generate wheels one by one
	docker run --rm=true -t -i -v py_mini_racer_build_volume:/code pyminiracer_py_mini_racer_py27
	docker run --rm=true -t -i -v py_mini_racer_build_volume:/code pyminiracer_py_mini_racer_py34
	docker run --rm=true -t -i -v py_mini_racer_build_volume:/code pyminiracer_py_mini_racer_py35
	# Fix them
	docker run --rm=true -t -i -v py_mini_racer_build_volume:/code pyminiracer_py_mini_racer_auditwheel_repair
	# List generated wheels
	docker run --rm=true -t -i -v py_mini_racer_build_volume:/code ubuntu ls /code/wheelhouse
	# Recover them
	docker run --rm=true -v py_mini_racer_build_volume:/code -v $(shell pwd)/dist:/dist -w /code/wheelhouse ubuntu cp -rv . /dist/

install: clean
	python setup.py install
