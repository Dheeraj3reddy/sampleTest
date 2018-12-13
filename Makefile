ifndef SERVICE_NAME
$(error SERVICE_NAME is not set)
endif

# $sha is provided by jenkins
BUILDER_TAG?=$(or $(sha),$(SERVICE_NAME)-builder)
IMAGE_TAG=$(SERVICE_NAME)-s3

default: ci

login:
	@echo docker login -u ARTIFACTORY_USER -p ARTIFACTORY_API_TOKEN docker-asr-release.dr.corp.adobe.com
	@docker login -u $(ARTIFACTORY_USER) -p $(ARTIFACTORY_API_TOKEN) docker-asr-release.dr.corp.adobe.com

# This target is called by the Jenkins "ci" job. It builds and runs the builder image,
# which should build the project and run unit tests, and optionally, code coverage.
ci: run-builder
ifeq ($(RUN_COVERAGE),true)
	@echo Executing: docker run \
	-v `pwd`:/build:z \
	-e COVERALLS_SERVICE_NAME=$(COVERALLS_SERVICE_NAME) \
	-e COVERALLS_REPO_TOKEN=$(COVERALLS_REPO_TOKEN) \
	-e COVERALLS_ENDPOINT=$(COVERALLS_ENDPOINT) \
	-e CI_PULL_REQUEST=$(ghprbPullId) \
	-e ARTIFACTORY_API_TOKEN=*** \
	-e ARTIFACTORY_USER=$(ARTIFACTORY_USER) \
	$(BUILDER_TAG) /build/run-coverage.sh

	@docker run \
	-v `pwd`:/build:z \
	-e COVERALLS_SERVICE_NAME=$(COVERALLS_SERVICE_NAME) \
	-e COVERALLS_REPO_TOKEN=$(COVERALLS_REPO_TOKEN) \
	-e COVERALLS_ENDPOINT=$(COVERALLS_ENDPOINT) \
	-e CI_PULL_REQUEST=$(ghprbPullId) \
	-e ARTIFACTORY_API_TOKEN=$(ARTIFACTORY_API_TOKEN) \
	-e ARTIFACTORY_USER=$(ARTIFACTORY_USER) \
	$(BUILDER_TAG) /build/run-coverage.sh
else
	@echo "No test coverage to run"
endif

# Builds and runs the builder image, which builds the project and runs unit
# tests, and then prepares the artifacts for deployment (moving them into the hash
# folder, preparing the manifest, etc.). The results are placed in the current
# directory of the local file system.
run-builder: login
	docker build -t $(BUILDER_TAG) -f Dockerfile.build.mt .
	@echo Executing: docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX=$(PATH_PREFIX) \
	-e PUSH_ARTIFACTS=$(PUSH_ARTIFACTS) \
	-e ARTIFACTORY_API_TOKEN=*** \
	-e ARTIFACTORY_USER=$(ARTIFACTORY_USER) \
	$(BUILDER_TAG)

	@docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX=$(PATH_PREFIX) \
	-e PUSH_ARTIFACTS=$(PUSH_ARTIFACTS) \
	-e ARTIFACTORY_API_TOKEN=$(ARTIFACTORY_API_TOKEN) \
	-e ARTIFACTORY_USER=$(ARTIFACTORY_USER) \
	$(BUILDER_TAG)

# This target is called by the Jenkins "build" job.
# After running "run-builder" to produce the built static content on the local
# file system, this target picks up the content and packages it into a
# deployer image. This deployer image knows how to push the artifacts
# to S3 when run.
build: run-builder
	docker build -t $(IMAGE_TAG) .

# This target is called by the Jenkins "ui-test" job.
# Runs the uitest image to launch the UI test.
run-uitest: login
	docker build -t $(BUILDER_TAG) -f Dockerfile.build.mt .
	@echo Executing: docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX=$(PATH_PREFIX) \
	-e ARTIFACTORY_API_TOKEN=*** \
	-e ARTIFACTORY_USER=$(ARTIFACTORY_USER) \
	$(BUILDER_TAG) /build/run-uitest.sh

	@docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX=$(PATH_PREFIX) \
	-e ARTIFACTORY_API_TOKEN=$(ARTIFACTORY_API_TOKEN) \
	-e ARTIFACTORY_USER=$(ARTIFACTORY_USER) \
	$(BUILDER_TAG) /build/run-uitest.sh

### Targets below this line are used for development and debugging purposes only ###

build-deployer: login
	docker build -t $(IMAGE_TAG) .

run-build-image-interactively:
	docker run -v `pwd`:/build:z -i -t $(BUILDER_TAG) /bin/bash

run-deployer-image-interactively:
	@echo Executing: docker run \
	-e AWS_ACCESS_KEY_ID=*** \
	-e AWS_SECRET_ACCESS_KEY=*** \
	-e AWS_SESSION_TOKEN=*** \
	-e AWS_ROLE=$(AWS_ROLE) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	-e LOCK_PHRASE=$(LOCK_PHRASE) \
	-i -t $(IMAGE_TAG) /bin/bash

	@docker run \
	-e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	-e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	-e AWS_SESSION_TOKEN=$(AWS_SESSION_TOKEN) \
	-e AWS_ROLE=$(AWS_ROLE) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	-e LOCK_PHRASE=$(LOCK_PHRASE) \
	-i -t $(IMAGE_TAG) /bin/bash

run-deployer-image:
	@echo Executing: docker run \
	-e AWS_ACCESS_KEY_ID=*** \
	-e AWS_SECRET_ACCESS_KEY=*** \
	-e AWS_SESSION_TOKEN=*** \
	-e AWS_ROLE=$(AWS_ROLE) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	-e LOCK_PHRASE=$(LOCK_PHRASE) \
	-e DEPLOY_TEST_FOLDERS \
	-e rollback \
	$(IMAGE_TAG)

	@docker run \
	-e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	-e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	-e AWS_SESSION_TOKEN=$(AWS_SESSION_TOKEN) \
	-e AWS_ROLE=$(AWS_ROLE) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	-e LOCK_PHRASE=$(LOCK_PHRASE) \
	-e DEPLOY_TEST_FOLDERS \
	-e rollback \
	$(IMAGE_TAG)

