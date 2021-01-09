(use-modules (test) (ice-9 ftw) (srfi srfi-1))
(for-each
 (lambda (name) (primitive-load (string-append "tests/unit/" name)))
 (sort (filter (lambda (name) (string-suffix? ".scm" name))
               (scandir "tests/unit")) string<?))
(finish-tests)
