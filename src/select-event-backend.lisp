;;; Read local build configuration before ASDF loads raylib's native library.
;;; No builds/downloads and no replacement of an already loaded library.
(let* ((root (merge-pathnames "../" (uiop:pathname-directory-pathname *load-truename*)))
       (config (merge-pathnames ".event-build/event-backend.sexp" root)))
  (unless (equal "0" (uiop:getenv "LUT_EVENT_LOOP"))
    (when (probe-file config)
      (let* ((*read-eval* nil)
             (settings (with-open-file (stream config) (read stream nil nil)))
             (raylib (getf settings :raylib)) (cef (getf settings :cef)))
        (unless (eql 1 (getf settings :version)) (error "Unsupported LUT backend configuration: ~A" config))
        (when (and raylib (not (uiop:getenv "RAYLIB_LISP_LIBRARY_PATH")) (not (find-package :raylib)))
          (unless (and (stringp raylib) (probe-file (merge-pathnames
                     #+darwin "libraylib.dylib" #+win32 "raylib.dll" #-(or darwin win32) "libraylib.so"
                     (uiop:ensure-directory-pathname raylib))))
            (error "LUT event backend is missing. Run make event-backend-build in LUT."))
          (setf (uiop:getenv "RAYLIB_LISP_LIBRARY_PATH") raylib))
        (when (and cef (not (uiop:getenv "LUT_CEF_RUNTIME")))
          (unless (and (stringp cef) (probe-file (merge-pathnames
                     #+darwin "liblut_cef.dylib" #+win32 "lut_cef.dll" #-(or darwin win32) "liblut_cef.so"
                     (uiop:ensure-directory-pathname cef))))
            (error "LUT CEF runtime is missing. Run make event-backend-build in LUT."))
          (setf (uiop:getenv "LUT_CEF_RUNTIME") cef))))))
