(use-modules (test) (murmur dsp fft) (srfi srfi-4))
(test "FFT against a direct DFT oracle"
  (for-each
   (lambda (n)
     (let ((input (make-f64vector n 0.0)))
       (do ((i 0 (+ i 1))) ((= i n)) (f64vector-set! input i (+ (sin i) (* 0.1 i))))
       (call-with-values
           (lambda () (fft-real input))
         (lambda (real imag)
           (do ((k 0 (+ k 1))) ((= k n))
             (let ((expected 0.0))
               (do ((j 0 (+ j 1))) ((= j n))
                 (set! expected (+ expected (* (f64vector-ref input j)
                                                (exp (* 0-6.283185307179586i (/ (* j k) n)))))))
               (check-near (real-part expected) (f64vector-ref real k) 1e-10)
               (check-near (imag-part expected) (f64vector-ref imag k) 1e-10)))
           (fft-execute! (make-fft-plan n) real imag #:inverse? #t)
           (do ((i 0 (+ i 1))) ((= i n))
             (check-near (f64vector-ref input i) (f64vector-ref real i) 1e-12)
             (check-near 0 (f64vector-ref imag i) 1e-12)))))) '(2 4 8 16 32)))
(test "FFT dimensions"
  (check-equal 1024 (next-power-of-two 700))
  (check-error 'fft (lambda () (make-fft-plan 3))))
