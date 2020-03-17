.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys

try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

BROWSER := python -c "$$BROWSER_PYSCRIPT"

.PHONY: help
help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)


# CLEAN TARGETS

.PHONY: clean-build
clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

.PHONY: clean-pyc
clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

.PHONY: clean-docs
clean-docs: ## remove previously built docs
	rm -f docs/api/*.rst
	-$(MAKE) -C docs clean 2>/dev/null  # this fails if sphinx is not yet installed

.PHONY: clean-coverage
clean-coverage: ## remove coverage artifacts
	rm -f .coverage
	rm -f .coverage.*
	rm -fr htmlcov/

.PHONY: clean-test
clean-test: ## remove test artifacts
	rm -fr .tox/
	rm -fr .pytest_cache

.PHONY: clean
clean: clean-build clean-pyc clean-test clean-coverage clean-docs ## remove all build, test, coverage, docs and Python artifacts


# INSTALL TARGETS

.PHONY: install
install: clean-build clean-pyc ## install the package to the active Python's site-packages
	pip install .

.PHONY: install-test
install-test: clean-build clean-pyc ## install the package and test dependencies
	pip install .[test]

.PHONY: install-develop
install-develop: clean-build clean-pyc ## install the package in editable mode and dependencies for development
	pip install -e .[dev]


# LINT TARGETS

.PHONY: lint
lint: ## check style with flake8 and isort
	flake8 greenguard tests
	isort -c --recursive greenguard tests

.PHONY: fix-lint
fix-lint: ## fix lint issues using autoflake, autopep8, and isort
	find greenguard -name '*.py' | xargs autoflake --in-place --remove-all-unused-imports --remove-unused-variables
	autopep8 --in-place --recursive --aggressive greenguard
	isort --apply --atomic --recursive greenguard

	find tests -name '*.py' | xargs autoflake --in-place --remove-all-unused-imports --remove-unused-variables
	autopep8 --in-place --recursive --aggressive tests
	isort --apply --atomic --recursive tests


# TEST TARGETS

.PHONY: test
test: ## run tests quickly with the default Python
	python -m pytest --basetemp=${ENVTMPDIR} --cov=greenguard

.PHONY: test-readme
test-readme: ## run the readme snippets
	rundoc run --single-session python3 -t python3 README.md

.PHONY: test-all
test-all: ## run tests on every Python version with tox
	tox -r

.PHONY: coverage
coverage: ## check code coverage quickly with the default Python
	coverage run --source greenguard -m pytest
	coverage report -m
	coverage html
	$(BROWSER) htmlcov/index.html


# DOCS TARGETS

.PHONY: docs
docs: clean-docs ## generate Sphinx HTML documentation, including API docs
	sphinx-apidoc --separate --no-toc -o docs/api/ greenguard
	$(MAKE) -C docs html

.PHONY: view-docs
view-docs: docs ## view docs in browser
	$(BROWSER) docs/_build/html/index.html

.PHONY: serve-docs
serve-docs: view-docs ## compile the docs watching for changes
	watchmedo shell-command -W -R -D -p '*.rst;*.md' -c '$(MAKE) -C docs html' docs


# RELEASE TARGETS

.PHONY: dist
dist: clean ## builds source and wheel package
	python setup.py sdist
	python setup.py bdist_wheel
	ls -l dist

.PHONY: test-publish
test-publish: dist ## package and upload a release on TestPyPI
	twine upload --repository-url https://test.pypi.org/legacy/ dist/*

.PHONY: publish
publish: dist ## package and upload a release
	twine upload dist/*

.PHONY: bumpversion-release
bumpversion-release: ## Merge master to stable and bumpversion release
	git checkout stable || git checkout -b stable
	git merge --no-ff master -m"make release-tag: Merge branch 'master' into stable"
	bumpversion release
	git push --tags origin stable

.PHONY: bumpversion-patch
bumpversion-patch: ## Merge stable to master and bumpversion patch
	git checkout master
	git merge stable
	bumpversion --no-tag patch
	git push

.PHONY: bumpversion-minor
bumpversion-minor: ## Bump the version the next minor skipping the release
	bumpversion --no-tag minor

.PHONY: bumpversion-major
bumpversion-major: ## Bump the version the next major skipping the release
	bumpversion --no-tag major

.PHONY: bumpversion-candidate
bumpversion-candidate: ## Bump the version to the next candidate
	bumpversion candidate --no-tag

CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)
CHANGELOG_LINES := $(shell git diff HEAD..origin/stable HISTORY.md 2>&1 | wc -l)

.PHONY: check-master
check-master: ## Check if we are in master branch
ifneq ($(CURRENT_BRANCH),master)
	$(error Please make the release from master branch\n)
endif

.PHONY: check-history
check-history: ## Check if HISTORY.md has been modified
ifeq ($(CHANGELOG_LINES),0)
	$(error Please insert the release notes in HISTORY.md before releasing)
endif

.PHONY: check-release
check-release: check-master check-history ## Check if the release can be made

.PHONY: release
release: check-release bumpversion-release publish bumpversion-patch

.PHONY: release-candidate
release-candidate: check-master publish bumpversion-candidate

.PHONY: release-minor
release-minor: check-release bumpversion-minor release

.PHONY: release-major
release-major: check-release bumpversion-major release


# DOCKER TARGETS

.PHONY: docker-jupyter-clean
docker-jupyter-clean: ## Remove the greenguard-jupyter docker image
	docker rmi -f greenguard-jupyter

.PHONY: docker-jupyter-build
docker-jupyter-build:  ## Build the greenguard-jupyter docker image using repo2docker
	docker build -t greenguard-jupyter .

.PHONY: docker-jupyter-save
docker-jupyter-save: docker-jupyter-build  ## Build the greenguard-jupyter image and save it as greenguard-jupyter.tar
	docker save --output greenguard-jupyter.tar greenguard-jupyter

.PHONY: docker-jupyter-load
docker-jupyter-load: ## Load the greenguard-jupyter image from greenguard-jupyter.tar
	docker load --input greenguard-jupyter.tar

.PHONY: docker-jupyter-run
docker-jupyter-run: ## Run the greenguard-jupyter image in editable mode
	docker run --rm -v $(shell pwd):/greenguard -ti -p8888:8888 --name greenguard-jupyter greenguard-jupyter

.PHONY: docker-jupyter-start
docker-jupyter-start: ## Start the greenguard-jupyter image as a daemon
	docker run --rm -d -v $(shell pwd):/greenguard -ti -p8888:8888 --name greenguard-jupyter greenguard-jupyter

.PHONY: docker-jupyter-stop
docker-jupyter-stop: ## Stop the greenguard-jupyter daemon
	docker stop greenguard-jupyter

.PHONY: docker-jupyter-push
docker-jupyter-push: docker-jupyter-build ## Push the docker image to Dockerhub
	docker tag greenguard-jupyter:latest mlbazaar/greenguard:jupyter
	docker push mlbazaar/greenguard:jupyter
	docker push
