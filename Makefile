ifndef SERVICE_NAME
$(error SERVICE_NAME is not set)
endif

# $sha is provided by jenkins
BUILDER_TAG?=$(or $(sha),$(SERVICE_NAME)-builder)

IMAGE_TAG_S3=$(SERVICE_NAME)-s3
IMAGE_TAG_NGINX=$(SERVICE_NAME)-nginx

default: ci

# This target is called by the Jenkins "ci" job. For now it just builds the builder image,
# but we plan to include unit testing as part of this target.
ci: build-builder

# Builds the intermediate builder image, responsible for doing the npm build and preparing
# the artifacts for deployment (moving them into the hash folder, preparing the manifest, etc.).
build-builder:
	docker build --build-arg PATH_PREFIX=$(PATH_PREFIX) -t $(BUILDER_TAG) -f Dockerfile.build .

# This target is called by the Jenkins "build" job.
# Runs the builder image and pipes the output (tarred artifacts) into the build for the S3 image.
# This S3 image knows how to push the artifacts to S3 when run.
build-s3: build-builder
	docker run $(BUILDER_TAG) | docker build -t $(IMAGE_TAG_S3) -f Dockerfile.s3 -


### Targets below this line are used for development and debugging purposes only ###

run-build-image-interactively: build-builder
	docker run -i -t $(BUILDER_TAG) /bin/bash

run-s3-image-interactively: build-s3
	@echo Executing: docker run \
	-e AWS_ACCESS_KEY_ID=*** \
	-e AWS_SECRET_ACCESS_KEY=*** \
	-e AWS_SESSION_TOKEN=*** \
	-e AWS_ROLE=$(AWS_ROLE) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	-i -t $(IMAGE_TAG_S3) /bin/bash

	@docker run \
	-e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	-e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	-e AWS_SESSION_TOKEN=$(AWS_SESSION_TOKEN) \
	-e AWS_ROLE=$(AWS_ROLE) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	-i -t $(IMAGE_TAG_S3) /bin/bash

run-s3-image: build-s3
	@echo Executing: docker run \
	-e AWS_ACCESS_KEY_ID=*** \
	-e AWS_SECRET_ACCESS_KEY=*** \
	-e AWS_SESSION_TOKEN=*** \
	-e AWS_ROLE=$(AWS_ROLE) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	$(IMAGE_TAG_S3)

	@docker run \
	-e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	-e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	-e AWS_SESSION_TOKEN=$(AWS_SESSION_TOKEN) \
	-e AWS_ROLE=$(AWS_ROLE) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	$(IMAGE_TAG_S3)

build-nginx: build-builder
	docker run $(BUILDER_TAG) | docker build -t $(IMAGE_TAG_NGINX) -f Dockerfile.nginx -

run-nginx-image-interactively: build-nginx
	docker run -i -t $(IMAGE_TAG_NGINX) /bin/bash
