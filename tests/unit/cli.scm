(use-modules (test) (murmur cli))
(test "CLI usage errors are structured, not handler failures"
  (let ((code #f))
    (let ((message (call-with-output-string
                   (lambda (port)
                     (parameterize ((current-error-port port))
                       (set! code (main '("murmur" "unknown-command"))))))))
      (check-equal 2 code)
      (check (string-contains message "murmur: usage:")))))
(test "CLI read failures have a stable nonzero exit"
  (let ((code #f))
    (call-with-output-string
     (lambda (port) (parameterize ((current-error-port port))
                     (set! code (main '("murmur" "inspect" "/missing/murmur.wav"))))))
    (check-equal 1 code)))
