(use-modules (test) (murmur project parse) (murmur project model))
(define minimal '(murmur (version 1) (source field (path "field.wav"))
                         (clip intro (source field) (from 0) (to 2))))
(test "minimal edit document"
  (let ((p (parse-project minimal)))
    (check-equal 48000 (project-rate p))
    (check-equal 'intro (clip-id (car (project-clips p))))
    (check-equal "field.wav" (source-path (car (project-sources p))))))
(test "project schema negative paths"
  (for-each
   (lambda (extra)
     (check-error 'schema (lambda () (parse-project (append minimal (list extra))))))
   '((version 2) (unknown 3) (clip intro (source field) (to 3))
     (clip other (source missing) (to 3)) (redact field (from 2) (to 1))
     (clip bad (source field) (to 1) (fade-in 1) (fade-out 1)))))
