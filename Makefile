# Set the shell to bash.
SHELL := /bin/bash -e -o pipefail

# Enable a verbose output from the makesystem.
VERBOSE ?= no

# Disable the colorized output from make if either
# explicitly overridden or if no tty is attached.
DISABLE_COLORS ?= $(shell [ -t 0 ] && echo no)

# Silence echoing the commands being invoked unless
# overridden to be verbose.
ifneq ($(VERBOSE),yes)
    silent := @
else
    silent :=
endif

# Configure colors.
ifeq ($(DISABLE_COLORS),no)
    COLOR_BLUE    := \x1b[1;34m
    COLOR_RESET   := \x1b[0m
else
    COLOR_BLUE    :=
    COLOR_RESET   :=
endif

# Common utilities.
ECHO := echo -e

# docker and related binaries.
DOCKER_CMD         := docker

# Build properties.
USER_NAME         ?= tuxdude
IMAGE_NAME        ?= homelab-base
IMAGE_TAG         ?= latest
FULL_IMAGE_NAME   := $(USER_NAME)/$(IMAGE_NAME):$(IMAGE_TAG)

# Commands invoked from rules.
DOCKERBUILD        := $(DOCKER_CMD) build --pull
DOCKERTEST := $(DOCKER_CMD) run --rm $(FULL_IMAGE_NAME) sh -c 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install nginx'

# Helpful functions
# ExecWithMsg
# $(1) - Message
# $(2) - Command to be executed
define ExecWithMsg
    $(silent)$(ECHO) "\n===  $(COLOR_BLUE)$(1)$(COLOR_RESET)  ==="
    $(silent)$(2)
endef

all: build test

clean:
	$(call ExecWithMsg,Cleaning,)

build:
	$(call ExecWithMsg,Building,$(DOCKERBUILD) --tag "$(FULL_IMAGE_NAME)" .)

test:
	$(call ExecWithMsg,Testing,$(DOCKERTEST))

.PHONY: all clean build test
