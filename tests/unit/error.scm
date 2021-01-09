(use-modules (test) (murmur error))
(test "numeric domain"
  (check (finite-real? 1/3))
  (check (finite-real? 0.0))
  (check (not (finite-real? +nan.0)))
  (check (not (finite-real? +inf.0)))
  (check (not (finite-real? 1+2i)))
  (check (exact-integer-in? 4 0 5))
  (check (not (exact-integer-in? 4.0 0 5))))
(test "structured failure"
  (check-error 'invalid (lambda () (ensure #f 'invalid "bad value" 42))))
