(use-modules (test) (murmur dsp biquad) (murmur buffer) (murmur wave encode) (murmur binary))
(test "filter transfer functions"
  (let ((lp (biquad-coefficients 'lowpass 48000 1000))
        (hp (biquad-coefficients 'highpass 48000 1000))
        (notch (biquad-coefficients 'notch 48000 1000 #:q 10)))
    (check-near 1 (magnitude (biquad-response lp 0)) 1e-12)
    (check-near 0 (magnitude (biquad-response hp 0)) 1e-12)
    (check-near (sqrt 0.5) (magnitude (biquad-response lp (* 6.283185307179586 1000/48000))) 1e-12)
    (check (< (magnitude (biquad-response notch (* 6.283185307179586 1000/48000))) 1e-12)))
  (check-error 'filter (lambda () (biquad-coefficients 'lowpass 8000 4000))))
(test "filter state is independent of blocking"
  (let* ((a (make-audio 8000 2 1000)) (coeff (biquad-coefficients 'highpass 8000 80))
         (whole (make-biquad 8000 2 coeff)) (split (make-biquad 8000 2 coeff)))
    (audio-map! a (lambda (x c i) (+ 0.2 (* 0.3 (sin (+ c (* 0.2 i)))))))
    (let ((expected (encode-pcm (whole (audio-copy a)))))
      (check-equal expected
        (bytes-append (encode-pcm (split (audio-slice a 0 317)))
                      (encode-pcm (split (audio-slice a 317 1000))))))))
