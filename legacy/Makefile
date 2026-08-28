# plone-legacy-images
# All tooling runs via docker: no local installs required.

IMAGE_PREFIX ?= plone-legacy
DOCKER ?= docker

# D3: these images are linux/amd64 only. Without an explicit --platform, an
# arm64 host (Apple Silicon) silently builds an arm64 image, and Python 2.4.6
# (2008) predates aarch64 support entirely. Pinning the platform here makes
# the build reproducible on any host; on arm64 it runs under emulation.
PLATFORM ?= linux/amd64

# Every implemented series, oldest first. Keep in sync with the directories,
# the matrix in README.md, and the ALL list in
# ../.github/workflows/legacy-build.yml. One series lands per pull request;
# append here as each one is ported.
SERIES := 3.0 3.1 3.2 3.3 4.0 4.1 4.2

# Builder used for the -demo images, which MUST be a `docker`-driver one:
# demo/Dockerfile's FROM reads the base image out of the local image store, and
# a docker-container builder cannot see it.
#
# Empty by default, i.e. "use whatever is current" — which is right locally,
# where the active builder follows the docker context. [V 2026-08-20] Hardcoding
# `default` here does NOT work on Docker Desktop: the current context is
# `desktop-linux`, and naming a builder bound to another context fails with
# "use `docker --context=default buildx` to switch to context default".
# CI sets DEMO_BUILDER=default, where the context genuinely is `default`.
DEMO_BUILDER ?=
DEMO_BUILDER_FLAG := $(if $(DEMO_BUILDER),--builder $(DEMO_BUILDER),)

# Deliberately NOT `admin`. `make test-demo-<v>` starts the container with this
# password, so the gate proves two things at once: that ADMIN_PASSWORD reaches
# a pre-seeded database at all, and that the build-time password stops working
# once it does. Testing with `admin` would pass on an image that ignored the
# variable entirely.
DEMO_TEST_PASSWORD ?= smoke-not-admin

# series -> full version (keep in sync with the matrix in README.md)
# [V 2026-08-20] 4.2.6, not the final 4.2.7: 4.2.7 has no UnifiedInstaller
# published, and the installer is what carries the offline buildout-cache
# these images are built from.
# [V 2026-08-20] 4.1.6 is both the final 4.1.x release and the last
# UnifiedInstaller published for the series, so this row needs no compromise.
# [V 2026-08-20] 3.0.5, not 3.0.6: the 3.0.6 roll shipped only as
# PloneBase-3.0.6.tar.gz (the stripped core, without dependency products).
# The last full Plone-*.tar.gz for the series is 3.0.5.
FULL_VERSION_3.0 := 3.0.5
FULL_VERSION_3.1 := 3.1.7
FULL_VERSION_3.2 := 3.2.3
FULL_VERSION_3.3 := 3.3.6
# [V 2026-08-20] 4.0.9, not 4.0.10: 4.0.10 is the final release and its egg
# set exists at dist.plone.org/release/4.0.10/, but Launchpad published no
# UnifiedInstaller past 4.0.9 — and the installer is what carries the offline
# buildout-cache these images are built from.
FULL_VERSION_4.0 := 4.0.9
FULL_VERSION_4.1 := 4.1.6
FULL_VERSION_4.2 := 4.2.6

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_.%-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS=":.*## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: plone-%
plone-%: ## Build the image for a series, e.g. make plone-2.1
	@test -d $* || { echo "No directory $*/ — not implemented yet"; exit 1; }
	$(DOCKER) build \
		--platform $(PLATFORM) \
		-f $*/Dockerfile \
		-t $(IMAGE_PREFIX):$(FULL_VERSION_$*) \
		-t $(IMAGE_PREFIX):$* \
		.

# ORDER MATTERS, and not for style. `test-demo-2.1` matches BOTH `test-demo-%`
# (stem "2.1") and `test-%` (stem "demo-2.1"). GNU make >= 3.82 resolves that by
# preferring the shortest stem — but macOS ships **3.81**, which takes the first
# matching pattern in definition order instead. So `test-demo-%` MUST be defined
# before `test-%`.
#
# [V 2026-08-20] Observed, not assumed: with `test-%` defined first, `make
# test-demo-2.1` ran the wrong recipe and expanded FULL_VERSION_demo-2.1 to
# nothing, which reached docker as the tag `plone-legacy:` and failed with
# "invalid reference format" — a message that says nothing about make.
# The version guard below turns that class of mistake into a clear error.
define require_version
	@test -n "$(FULL_VERSION_$(1))" || { \
		echo "No FULL_VERSION_$(1) in the Makefile — is '$(1)' a real series?"; \
		exit 1; \
	}
endef

.PHONY: test-demo-%
test-demo-%: ## Smoke-test a built -demo image, e.g. make test-demo-2.1
	$(call require_version,$*)
	SMOKE_EXPECT_SITE=1 \
	SMOKE_ADMIN_PASSWORD=$(DEMO_TEST_PASSWORD) \
	IMAGE=$(IMAGE_PREFIX):$(FULL_VERSION_$*)-demo ./shared/smoke-test.sh

.PHONY: test-%
test-%: ## Smoke-test a built image, e.g. make test-2.1
	$(call require_version,$*)
	IMAGE=$(IMAGE_PREFIX):$(FULL_VERSION_$*) ./shared/smoke-test.sh

# Defined BEFORE demo-% for the same GNU Make 3.81 reason as test-demo-%.
#
# The demo layer alone, assuming the base image is already in the local image
# store. CI uses this: it has just loaded the base there from its own gha-cached
# build, and `make demo-%` would rebuild it against a different cache.
#
# The builder matters here: `FROM ${BASE_IMAGE}` resolves against the DAEMON's
# images, and only the `docker` driver can read those. The docker-container
# driver that docker/setup-buildx-action makes default in CI cannot, and reports
# the base image as `pull access denied` rather than as unreadable — hence
# DEMO_BUILDER above, which CI sets and a local run leaves alone.
.PHONY: demo-image-%
demo-image-%: ## Build only the -demo layer, reusing the base image already built
	$(call require_version,$*)
	$(DOCKER) buildx build $(DEMO_BUILDER_FLAG) \
		--platform $(PLATFORM) \
		-f demo/Dockerfile \
		--build-arg BASE_IMAGE=$(IMAGE_PREFIX):$(FULL_VERSION_$*) \
		-t $(IMAGE_PREFIX):$(FULL_VERSION_$*)-demo \
		-t $(IMAGE_PREFIX):$*-demo \
		.

.PHONY: demo-%
demo-%: ## Build the -demo variant for a series (site pre-created), e.g. make demo-2.1
	@test -d $* || { echo "No directory $*/ — not implemented yet"; exit 1; }
	$(call require_version,$*)
	$(MAKE) plone-$*
	$(MAKE) demo-image-$*

.PHONY: demos
demos: ## Build every -demo image (slow: each one boots Zope and creates a site)
	@for v in $(SERIES); do $(MAKE) demo-$$v || exit 1; done

.PHONY: test-demos
test-demos: ## Smoke-test every built -demo image
	@for v in $(SERIES); do $(MAKE) test-demo-$$v || exit 1; done

.PHONY: lint
lint: ## Lint Dockerfiles (hadolint), shell scripts (shellcheck), workflows (yaml well-formedness)
	@set -e; for f in */Dockerfile; do \
		echo "hadolint $$f"; \
		$(DOCKER) run --rm -v "$(CURDIR):/mnt:ro" -w /mnt \
			hadolint/hadolint hadolint "$$f"; \
	done
	@echo "shellcheck shared/*.sh"
	@$(DOCKER) run --rm -v "$(CURDIR):/mnt:ro" koalaman/shellcheck:stable \
		-s sh shared/*.sh
	@echo "yaml check ../.github/workflows/legacy-build.yml"
	@$(DOCKER) run --rm -v "$(CURDIR)/..:/data:ro" mikefarah/yq:4 \
		-e 'true' /data/.github/workflows/legacy-build.yml >/dev/null
	@echo "lint OK"

.PHONY: format
format: ## Format shell scripts in place (shfmt)
	$(DOCKER) run --rm -v "$(CURDIR):/mnt" -w /mnt mvdan/shfmt:latest \
		-w -i 4 -ci shared/

.PHONY: clean
clean: ## Remove locally built images for all series, base and -demo alike
	-@for v in $(SERIES); do \
		$(DOCKER) rmi -f $(IMAGE_PREFIX):$$v 2>/dev/null; \
		$(DOCKER) rmi -f $(IMAGE_PREFIX):$$v-demo 2>/dev/null; \
	done
