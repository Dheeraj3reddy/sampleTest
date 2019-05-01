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
#
# Ethos and Document Cloud build infrastructure requires that images be tagged in a standard way (see IMAGE_TAG above)
# so that the infrastructure can find them after building. Unlike Ethos, however, Document Cloud currently executes
# our ci jobs on the same Jenkins servers as our build jobs. In order to avoid accidentally publishing the wrong image
# (i.e. when a ci job and a build job run at the same time) we override the image tag for ci jobs by adding a git sha
# provided by Jenkins.
ci: IMAGE_TAG := $(if $(sha),$(IMAGE_TAG)-ci-$(sha),$(IMAGE_TAG))
ci: build
ifeq ($(RUN_COVERAGE),true)
	docker run \
	-v `pwd`:/build:z \
	-e COVERALLS_SERVICE_NAME \
	-e COVERALLS_REPO_TOKEN \
	-e COVERALLS_ENDPOINT \
	-e CI_PULL_REQUEST=$(ghprbPullId) \
	-e ARTIFACTORY_API_TOKEN \
	-e ARTIFACTORY_USER \
	$(BUILDER_TAG) /build/run-coverage.sh
else
	echo "No test coverage to run"
endif

# This target is called by the Jenkins "build" job.
build: login
	# First, build and run the builder image.
	docker build -t $(BUILDER_TAG) -f Dockerfile.build.mt .
	# Run the builder image to do the actual code build, run unit tests,
	# and prepare the artifacts for deployment (move them into the hash
	# folder, prepare the manifest, etc.). The results are placed in the current
	# directory of the local file system.
	docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX \
	-e PUSH_ARTIFACTS \
	-e ARTIFACTORY_API_TOKEN \
	-e ARTIFACTORY_USER \
	-e TESSA2_API_KEY \
	$(BUILDER_TAG)
	# Package the built content it into a deployer image.
	# This deployer image knows how to push the artifacts to S3 when run.
	docker build -t $(IMAGE_TAG) .

# This target is called by the Jenkins "ui-test" job.
# Runs the uitest image to launch the UI test.
run-uitest: login
	docker build -t $(BUILDER_TAG) -f Dockerfile.build.mt .
	docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX \
	-e ARTIFACTORY_API_TOKEN \
	-e ARTIFACTORY_USER \
	$(BUILDER_TAG) /build/run-uitest.sh

### Targets below this line are used for development and debugging purposes only ###

run-build-image-interactively:
	docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX \
	-e PUSH_ARTIFACTS \
	-e ARTIFACTORY_API_TOKEN \
	-e ARTIFACTORY_USER \
	-e TESSA2_API_KEY \
	-i -t $(BUILDER_TAG) /bin/bash

run-deployer-image-interactively:
	docker run \
	-e AWS_ACCESS_KEY_ID \
	-e AWS_SECRET_ACCESS_KEY \
	-e AWS_SESSION_TOKEN \
	-e AWS_ROLE \
	-e S3_BUCKETS \
	-e LOCK_PHRASE \
	-e DEPLOY_TEST_FOLDERS \
	-e rollback \
	-i -t $(IMAGE_TAG) /bin/bash

run-deployer-image:
	docker run \
	-e AWS_ACCESS_KEY_ID \
	-e AWS_SECRET_ACCESS_KEY \
	-e AWS_SESSION_TOKEN \
	-e AWS_ROLE \
	-e S3_BUCKETS \
	-e LOCK_PHRASE \
	-e DEPLOY_TEST_FOLDERS \
	-e rollback \
	$(IMAGE_TAG)
