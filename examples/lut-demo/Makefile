SBCL ?= sbcl

.PHONY: run test smoke
run:
	$(SBCL) --script scripts/run.lisp

test:
	$(SBCL) --script scripts/test.lisp

smoke:
	$(SBCL) --script scripts/smoke.lisp
