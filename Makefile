GUILE ?= guile
RUN = GUILE_AUTO_COMPILE=0 $(GUILE) --no-auto-compile -L src -L tests
.DEFAULT_GOAL := all

.PHONY: all build test check demo clean
all: build

build:
	$(RUN) scripts/build.scm

test:
	$(RUN) tests/run.scm

check: build test

demo: build
	mkdir -p build
	@if [ -d build/demo ]; then bin/murmur verify build/demo/review; else bin/murmur demo build/demo; fi

clean:
	rm -rf .cache/compiled
