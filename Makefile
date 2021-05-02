GUILE ?= guile
CC ?= cc
SHARED_FLAGS := $(if $(filter Darwin,$(shell uname -s)),-dynamiclib,-shared -fPIC)
RUN = GUILE_AUTO_COMPILE=0 $(GUILE) --no-auto-compile -L src -L tests
.DEFAULT_GOAL := all

.PHONY: all build native test check demo clean
all: build

native: .cache/native/fingerprint.so

.cache/native/fingerprint.so: native/fingerprint.c
	mkdir -p .cache/native
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 $(SHARED_FLAGS) $< -o $@

build: native
	$(RUN) scripts/build.scm

test: native
	$(RUN) tests/run.scm

check: build test

demo: build
	mkdir -p build
	@if [ -d build/demo ]; then bin/murmur verify build/demo/review; else bin/murmur demo build/demo; fi

clean:
	rm -rf .cache/compiled .cache/native
