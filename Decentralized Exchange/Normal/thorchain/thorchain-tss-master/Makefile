.PHONY: install build test test-watch lint tools

all: lint build

clear:
	clear

tools:
	go install ./tools/tss-recovery

install: go.sum
	go install ./cmd/tss

go.sum: go.mod
	@echo "--> Ensure dependencies have not been modified"
	go mod verify

test:
	@go test ./...

test-watch: clear
	@gow -c test -tags testnet -mod=readonly ./...

lint-pre:
	@gofumpt -l cmd common keygen keysign messages p2p storage tss # for display
	@test -z "$(shell gofumpt -l cmd common keygen keysign messages p2p storage tss)" # cause error
	@go mod verify

lint: lint-pre
	@golangci-lint run

lint-verbose: lint-pre
	@golangci-lint run -v

build:
	@go build ./...

# ------------------------------- GitLab ------------------------------- #
docker-gitlab-login:
	docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}

docker-gitlab-push:
	docker push registry.gitlab.com/thorchain/tss/go-tss

docker-gitlab-build:
	docker build -t registry.gitlab.com/thorchain/tss/go-tss .
	docker tag registry.gitlab.com/thorchain/tss/go-tss $$(git rev-parse --short HEAD)
