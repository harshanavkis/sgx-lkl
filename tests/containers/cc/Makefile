include ../../common.mk

APP_ROOT=app
PROG=${APP_ROOT}/python-helloworld.py

DISK_IMAGE=rootfs.img
DATA_IMAGE=data.img
IMAGE_SIZE=100M

CC=python-helloworld-cc
CC_stamp=$(CC).stamp

# This test verifies in-enclave networking.

CC_DOCKER_ARGS_COMMON=\
	--rm \
	--user $(shell id -u) \
	--device /dev/net/tun --network host \
	-v $(SGXLKL_PREFIX):/opt/sgx-lkl \
	-e SGXLKL_VERBOSE=1 -e SGXLKL_KERNEL_VERBOSE=1 -e SGXLKL_TAP=sgxlkl_tap0 \
	-e AZDCAP_DEBUG_LOG_LEVEL=INFO

CC_DOCKER_ARGS_HW=\
	--device /dev/sgx

.DELETE_ON_ERROR:
.PHONY: run run-hw run-sw clean

$(DISK_IMAGE): $(PROG)
	${SGXLKL_DISK_TOOL} create --size=${IMAGE_SIZE} --docker=./Dockerfile ${DISK_IMAGE}

$(DATA_IMAGE): $(DISK_IMAGE)
	cp $(DISK_IMAGE) $(DATA_IMAGE)

$(CC_stamp): $(DISK_IMAGE) $(DATA_IMAGE)
	$(SGXLKL_DOCKER_TOOL) build --name=$(CC) --host-cfg=host-config.json --enclave-cfg=enclave-config.json
	touch $(CC_stamp)

run: run-hw run-sw

ifeq (${SGXLKL_PREFIX},)
run-hw:
	@echo SGXLKL_PREFIX missing, skipping test. See README.md.

run-sw:
	@echo SGXLKL_PREFIX missing, skipping test. See README.md.
else
run-hw: $(CC_stamp)
	docker run $(CC_DOCKER_ARGS_COMMON) $(CC_DOCKER_ARGS_HW) $(CC) --hw-debug

run-sw: $(CC_stamp)
	# TODO -t as work-around for https://github.com/lsds/sgx-lkl/issues/158
	docker run -t $(CC_DOCKER_ARGS_COMMON) $(CC) --sw-debug
endif

clean:
	rm -f $(DISK_IMAGE) $(DATA_IMAGE) $(CC) $(CC_stamp)
