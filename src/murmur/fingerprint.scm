;;; A stable seven-word ABI preserves nanosecond metadata even on Guile builds
;;; whose stat interface only exposes seconds. Access time is intentionally
;;; absent because merely reading a source must not invalidate its identity.
(define-module (murmur fingerprint)
  #:use-module (murmur error)
  #:use-module (system foreign)
  #:use-module (rnrs bytevectors)
  #:export (file-fingerprint))
(define native-call #f)
(define native-handle #f)
(define (load-adapter)
  (unless native-call
    (let ((path (search-path %load-path "../.cache/native/fingerprint.so")))
      (ensure path 'install "timestamp adapter missing; run make build")
      ;; Retain the handle for the full lifetime of the foreign procedure.
      (set! native-handle (dynamic-link path))
      (set! native-call (pointer->procedure int
                         (dynamic-func "murmur_fingerprint" native-handle) (list int '*))))))
(define (port-fingerprint port)
  (load-adapter)
  (let* ((bytes (make-bytevector 56 0)) (status (native-call (fileno port) (bytevector->pointer bytes))))
    (ensure (= status 0) 'source "cannot inspect source metadata" (strerror status))
    (list->vector (map (lambda (i) (bytevector-u64-native-ref bytes (* 8 i))) '(0 1 2 3 4 5 6)))))
(define (file-fingerprint file-or-port)
  (if (port? file-or-port) (port-fingerprint file-or-port)
      (call-with-input-file file-or-port port-fingerprint #:binary #t)))
