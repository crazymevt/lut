SBCL ?= sbcl

.PHONY: demo
demo:
	$(SBCL) --script tools/demo.lisp
