(use-modules (test) (fixtures) (murmur bundle) (murmur buffer) (murmur wave encode)
             (murmur wave scan) (murmur project model) (murmur redact) (murmur paths))
(test "a guard at the one-day boundary clips to the source"
  (with-bytes (encode-wave (make-audio 1 1 86400))
    (lambda (path)
      (let ((masks (compile-masks (list (make-redaction 'x 86399 86400 'mute 1 -18 1000)) (scan-wave path))))
        (check-equal 86400 (mask-end (vector-ref masks 0)))))))
(test "malformed manifest entries produce bundle diagnostics"
  (let ((base (mkdtemp "/tmp/murmur-malformed-XXXXXX")))
    (dynamic-wind
      (lambda () (write-text (string-append base "/manifest.mur")
                    "(murmur-bundle (version 1) (rate 8000) (channels 1) (frames 0) (file))"))
      (lambda () (check-error 'bundle (lambda () (verify-bundle base))))
      (lambda () (remove-private-tree base)))))
