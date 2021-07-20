SERVICE_NAME=cdnexample

# $sha is provided by the build system
BUILDER_TAG?=$(or $(sha),$(SERVICE_NAME)-builder)
IMAGE_TAG=$(SERVICE_NAME)-img

default: ci

login:
	@echo docker login -u ARTIFACTORY_USER -p ARTIFACTORY_API_TOKEN docker-asr-release.dr.corp.adobe.com
	@docker login -u $(ARTIFACTORY_USER) -p $(ARTIFACTORY_API_TOKEN) docker-asr-release.dr.corp.adobe.com

# This target is called by the build system's "ci" job.
#
# Ethos and Document Cloud build infrastructure requires that images be tagged in a standard way (see IMAGE_TAG above)
# so that the infrastructure can find them after building. Unlike Ethos, however, Document Cloud executes some of
# our ci jobs on the same Jenkins servers as our build jobs. In order to avoid accidentally publishing the wrong image
# (i.e. when a ci job and a build job run at the same time) we override the image tag for ci jobs by adding a git sha
# provided by Jenkins.
ci: IMAGE_TAG := $(if $(sha),$(IMAGE_TAG)-ci-$(sha),$(IMAGE_TAG))
ci: build

# This target is called by the build system's "build" job.
build: login
	# First, build and run the builder image.
	docker build --pull -t $(BUILDER_TAG) -f Dockerfile.build.mt .
	# Run the builder image to do the actual code build, run unit tests, run code coverage, update Tessa,
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
	-e SONAR_TOKEN \
	-e SONAR_ANALYSIS_TYPE \
	-e repo \
	-e sha \
	-e branch \
	-e base_branch \
	-e pr_numbers \
	$(BUILDER_TAG)
	# Package the built content it into a deployer image.
	# This deployer image knows how to push the artifacts to S3 when run.
	docker build --pull -t $(IMAGE_TAG) .

# This target is called by the build system's "ui-test" job.
# Runs the uitest image to launch the UI test.
run-uitest: login
	docker build --pull -t $(BUILDER_TAG) -f Dockerfile.build.mt .
	docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX \
	-e ARTIFACTORY_API_TOKEN \
	-e ARTIFACTORY_USER \
	$(BUILDER_TAG) /build/run-uitest.sh

# This target is called by the build system's "cdn-postmerge" job.
# Runs the build image to launch the post-merge script.
run-postmerge-hook: login
	docker build --pull -t $(BUILDER_TAG) -f Dockerfile.build.mt .
	docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX \
	-e ARTIFACTORY_API_TOKEN \
	-e ARTIFACTORY_USER \
	-e GITHUB_TOKEN \
	$(BUILDER_TAG) /build/run-postmerge-hook.sh

### Targets below this line are used for development and debugging purposes only ###

run-build-image-interactively:
	docker run \
	-v `pwd`:/build:z \
	-e PATH_PREFIX \
	-e PUSH_ARTIFACTS \
	-e ARTIFACTORY_API_TOKEN \
	-e ARTIFACTORY_USER \
	-e TESSA2_API_KEY \
	-e SONAR_TOKEN \
	-e SONAR_ANALYSIS_TYPE \
	-e repo \
	-e sha \
	-e branch \
	-e base_branch \
	-e pr_numbers \
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
