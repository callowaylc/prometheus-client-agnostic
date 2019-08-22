export SHELL=/bin/sh
export VERSION ?= 3.7-alpine
export PORT ?= 8080
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ARGS := $(or $(ARGS),test)
FLTR := $(firstword $(ARGS))
WKDR = /opt/bin

.PHONY: make sandbox
.SILENT: -

make:
	docker pull python:$(VERSION)

sandbox:
	docker run \
		--name client_agnostic-sandbox \
		--rm \
		-it \
		-p 0:$(PORT) \
		-e "PRIORITY=debug" \
		-v 	`realpath .`:$(WKDR):ro \
		--workdir $(WKDR) \
		--entrypoint $(WKDR)/entrypoint.sh \
			python:$(VERSION) $(ARGS)
