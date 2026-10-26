(asdf:defsystem "lui"
  :description "Portable retained-mode CLOS GUI core"
  :version "0.1.0" :license "MIT" :serial t
  :components ((:file "src/package") (:file "src/core") (:file "src/widgets") (:file "src/styles") (:file "src/input") (:file "src/interactions"))
  :in-order-to ((asdf:test-op (asdf:test-op "lui/tests"))))
(asdf:defsystem "lui/raylib" :depends-on ("lui" "raylib" "bordeaux-threads" "cl-base64")
  :serial t :components ((:file "src/raylib") (:file "src/windows")))
(asdf:defsystem "lui/examples" :depends-on ("lui/raylib")
  :components ((:file "examples/demos")))
(asdf:defsystem "lui/docs" :depends-on ("lui/raylib" "docset")
  :serial t :components ((:file "tools/contracts") (:file "tools/docset")))
(asdf:defsystem "lui/tests" :depends-on ("lui")
  :serial t :components ((:file "tests/core") (:file "tests/review") (:file "tests/lifecycle"))
  :perform (asdf:test-op (op c) (declare (ignore op c))
             (uiop:symbol-call :lui-tests :run-tests)
             (uiop:symbol-call :lui-tests :review-tests)
             (uiop:symbol-call :lui-tests :widget-coverage-tests)
             (uiop:symbol-call :lui-tests :lifecycle-tests)))

(asdf:defsystem "lui/gtk-demo" :depends-on ("lui" "classowary" "xmls" "cl-pdf-parser")
 :serial t :components ((:file "examples/gtk-demo") (:file "examples/gtk/common") (:file "examples/gtk/controls") (:file "examples/gtk/text-and-widgets") (:file "examples/gtk/data") (:file "examples/gtk/games") (:file "examples/gtk/graphics") (:file "examples/gtk/paths") (:file "examples/gtk/layouts") (:file "examples/gtk/input-and-transfer") (:file "examples/gtk/typography") (:file "examples/gtk/media") (:file "examples/gtk/appearance") (:file "examples/gtk/expanded-controls") (:file "examples/gtk/coverage")))
(asdf:defsystem "lui/gtk-demo-tests" :depends-on ("lui/gtk-demo")
 :perform (asdf:test-op (op c) (declare (ignore op c))
             (uiop:symbol-call :lui-gtk-demo :test-demos)))

(asdf:defsystem "lui/gc-tests" :depends-on ("lui/raylib" "trivial-garbage")
 :components ((:file "tests/gc"))
 :perform (asdf:test-op (op c) (declare (ignore op c))
            (uiop:symbol-call :lui-gc-tests :run-tests)))

(asdf:defsystem "lui/gtk-demo-native" :depends-on ("lui/raylib" "lui/gtk-demo")
 :components ((:file "examples/gtk/native")))

(asdf:defsystem "lui/gtk-demo-gc-tests" :depends-on ("lui/gtk-demo" "lui/gc-tests")
 :components ((:file "tests/demo-gc"))
 :perform (asdf:test-op (op c) (declare (ignore op c))
            (uiop:symbol-call :lui-demo-gc-tests :run-tests)))
