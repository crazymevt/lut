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

.PHONY: test-widget-cache-ui benchmark-widget-cache
test-widget-cache-ui:
	$(SBCL) --script tests/widget-cache-native.lisp
	$(SBCL) --script tests/idle-native.lisp

benchmark-widget-cache:
	$(SBCL) --script tests/widget-cache-performance.lisp

.PHONY: webview test-webview
webview:
	$(SBCL) --script webview/scripts/run.lisp

test-webview:
	$(SBCL) --script webview/tests/headless.lisp
