GUILE ?= guile
RUN = GUILE_AUTO_COMPILE=0 $(GUILE) --no-auto-compile -L src -L tests

.PHONY: test check

test:
	$(RUN) tests/run.scm

check: test
