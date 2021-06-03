(use-modules (test) (murmur random))
(test "counter noise domains"
  (check-equal 0 (mix32 0))
  (check-equal 1753845952 (mix32 1))
  (check-equal (mix32 7) (mix32 (+ 7 (expt 2 32))))
  (let ((sum 0.0) (energy 0.0))
    (do ((i 0 (+ i 1))) ((= i 10000))
      (let ((x (white-at 7 0 i)))
        (check (<= -1 x 1))
        (set! sum (+ sum x)) (set! energy (+ energy (* x x)))))
    (check (< (abs (/ sum 10000)) 0.03))
    (check (< 0.30 (/ energy 10000) 0.36)))
  (check (not (= (uniform-at 7 0 100 0) (uniform-at 7 1 100 0))))
  (check-error 'random (lambda () (white-at -1 0 1))))
(test "word products agree with arbitrary-precision arithmetic"
  (for-each
   (lambda (a)
     (for-each
      (lambda (b) (check-equal (modulo (* a b) 4294967296) (mul32 a b)))
      '(0 1 65535 65536 2147483648 4294967295)))
   '(0 1 65535 65536 2147483648 4294967295)))
