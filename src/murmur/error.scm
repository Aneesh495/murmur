;;; Structured failures are the public error boundary. Internal Scheme failures
;;; remain distinguishable so the CLI never disguises a programming defect.
(define-module (murmur error)
  #:export (fail ensure finite-real? exact-integer-in?))

(define (fail code message . context)
  (throw 'murmur code message context))

(define (ensure condition code message . context)
  (unless condition (apply fail code message context)))

(define (finite-real? value)
  (and (real? value) (not (nan? value)) (not (inf? value))))

(define (exact-integer-in? value low high)
  (and (exact-integer? value) (<= low value high)))
