(use-modules (test) (murmur paths) (murmur binary) (rnrs bytevectors))
(test "staging publication and cleanup"
  (let* ((base (mkdtemp "/tmp/murmur-test-XXXXXX")) (out (string-append base "/out")))
    (dynamic-wind
      (lambda () #t)
      (lambda ()
        (with-staging-directory out
          (lambda (stage) (write-file-bytes (string-append stage "/x") #vu8(1))))
        (check-equal #vu8(1) (read-file-bytes (string-append out "/x")))
        (check-error 'exists (lambda () (with-staging-directory out (lambda (_) #f))))
        (check-error 'deliberate
          (lambda () (with-staging-directory (string-append base "/bad")
                       (lambda (_) ((module-ref (resolve-interface '(murmur error)) 'fail)
                                    'deliberate "abort")))))
        (check (not (exists-any? (string-append base "/bad"))))
        (let ((stage (mkdtemp (string-append base "/stage-XXXXXX"))))
          (check-error 'publish (lambda () (publish-directory stage out)))
          (check (exists-any? stage))))
      (lambda () (remove-private-tree base)))))
