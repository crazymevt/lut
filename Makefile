SBCL ?= sbcl

.PHONY: demo lut-demo test-lut-demo smoke-lut-demo
demo:
	$(SBCL) --script tools/demo.lisp

lut-demo:
	$(SBCL) --script examples/lut-demo/scripts/run.lisp

test-lut-demo:
	$(SBCL) --script examples/lut-demo/scripts/test.lisp

smoke-lut-demo:
	$(SBCL) --script examples/lut-demo/scripts/smoke.lisp

.PHONY: test-render-cache-ui
test-render-cache-ui:
	$(SBCL) --non-interactive --load tests/render-cache-native.lisp

.PHONY: test-data-renderer-ui
test-data-renderer-ui:
	$(SBCL) --non-interactive --load tests/data-renderer-native.lisp
