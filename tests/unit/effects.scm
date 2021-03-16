(use-modules (test) (murmur effects) (murmur buffer))
(test "effect registry rejects typos before rendering"
  (check-error 'effect (lambda () (compile-effects '((unknown)) 8000 8000)))
  (check-error 'schema (lambda () (compile-effects '((limit (ceilng-db -3))) 8000 8000)))
  (check-error 'effect (lambda () (compile-effects '((denoise (profile-from 0) (profile-to 1/100))) 8000 8000))))
(test "offline effects and ordered processing"
  (let* ((effects (compile-effects '((remove-dc) (gain (db 6)) (normalize (peak-db -3))) 8000 1000))
         (process (make-effect-chain effects 1)) (a (make-audio 8000 1 1000)))
    (check (effects-offline? effects))
    (audio-map! a (lambda (x c i) (+ 0.3 (* 0.1 (sin (* 6.283185307179586 (/ i 100)))))))
    (process a)
    (check-near 0.7079457843841379 (audio-peak a) 1e-12)))
