ifndef SERVICE_NAME
$(error SERVICE_NAME is not set)
endif

# $sha is provided by Jenkins
BASE_NAME?=$(or $(sha), $(SERVICE_NAME))

BUILDER_TAG=$(BASE_NAME)-builder
IMAGE_TAG_S3=$(BASE_NAME)-s3
IMAGE_TAG_NGINX=$(BASE_NAME)-nginx

default: ci

build-build-image:
	docker build --build-arg PATH_PREFIX=$(PATH_PREFIX) -t $(BUILDER_TAG) -f Dockerfile.build .

build-s3: build-build-image
	docker run $(BUILDER_TAG) | docker build -t $(IMAGE_TAG_S3) -f Dockerfile.s3 -

# This target called by the Jenkins "ci" job
ci: build-build-image

# This target called by the Jenkins "build" job
tag-and-push-s3-image: build-s3
	docker tag $(IMAGE_TAG_S3) docker-asr-release.dr.corp.adobe.com/static-pipeline/$(SERVICE_NAME):$(IMAGE_TAG_S3)
	docker push docker-asr-release.dr.corp.adobe.com/static-pipeline/$(SERVICE_NAME):$(IMAGE_TAG_S3)

# This target called by the Jenkins "deploy" jobs
pull-and-run-s3-image:
	@echo Executing: docker run \
	-e AWS_ACCESS_KEY_ID=*** \
	-e AWS_SECRET_ACCESS_KEY=*** \
	-e AWS_SESSION_TOKEN=*** \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	docker-asr-release.dr.corp.adobe.com/static-pipeline/$(SERVICE_NAME):$(IMAGE_TAG_S3)

	@docker run \
	-e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	-e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	-e AWS_SESSION_TOKEN=$(AWS_SESSION_TOKEN) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	docker-asr-release.dr.corp.adobe.com/static-pipeline/$(SERVICE_NAME):$(IMAGE_TAG_S3)


### Targets below this line are used for development and debugging purposes only ###

run-build-image-interactively: build-build-image
	docker run -i -t $(BUILDER_TAG) /bin/bash

run-s3-image-interactively: build-s3
	@echo Executing: docker run \
	-e AWS_ACCESS_KEY_ID=*** \
	-e AWS_SECRET_ACCESS_KEY=*** \
	-e AWS_SESSION_TOKEN=*** \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	-i -t $(IMAGE_TAG_S3) /bin/bash

	@docker run \
	-e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	-e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	-e AWS_SESSION_TOKEN=$(AWS_SESSION_TOKEN) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	-i -t $(IMAGE_TAG_S3) /bin/bash

run-s3-image: build-s3
	@echo Executing: docker run \
	-e AWS_ACCESS_KEY_ID=*** \
	-e AWS_SECRET_ACCESS_KEY=*** \
	-e AWS_SESSION_TOKEN=*** \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	$(IMAGE_TAG_S3)

	@docker run \
	-e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	-e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	-e AWS_SESSION_TOKEN=$(AWS_SESSION_TOKEN) \
	-e S3_BUCKETS=$(S3_BUCKETS) \
	$(IMAGE_TAG_S3)

build-nginx: build-build-image
	docker run $(BUILDER_TAG) | docker build -t $(IMAGE_TAG_NGINX) -f Dockerfile.nginx -

run-nginx-image-interactively: build-nginx
	docker run -i -t $(IMAGE_TAG_NGINX) /bin/bash
