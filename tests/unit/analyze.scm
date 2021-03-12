(use-modules (test) (murmur analyze) (murmur json) (murmur buffer))
(test "meter follows the stream rather than block boundaries"
  (let* ((a (make-audio 8000 2 1000)) (whole (make-meter 8000 2 1000 17))
         (split (make-meter 8000 2 1000 17)))
    (audio-map! a (lambda (x c i) (* 0.5 (sin (+ c (* i 0.1))))))
    (meter-add! whole a)
    (meter-add! split (audio-slice a 0 101)) (meter-add! split (audio-slice a 101 1000))
    (check-equal (json->text (meter-finish whole)) (json->text (meter-finish split)))
    (check-error 'analysis (lambda () (meter-add! split a)))))
(test "empty analysis is finite JSON"
  (let ((m (make-meter 8000 1 0)))
    (check-equal 0 (meter-frames m))
    (check (string? (json->text (meter-finish m))))))
