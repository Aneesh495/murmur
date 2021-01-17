;;; Planar double-precision buffers keep channel routing explicit. Allocations
;;; pass one shared budget check before a vector is created.
(define-module (murmur buffer)
  #:use-module (murmur error)
  #:use-module (murmur clock)
  #:use-module (srfi srfi-4)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (audio? make-audio audio-rate audio-channels audio-frames audio-plane
            audio-ref audio-set! audio-copy audio-slice audio-map! audio-finite?
            audio-peak audio-rms audio-duration audio-bytes audio-mix! audio-clear!
            max-buffer-bytes check-region))

(define max-buffer-bytes (make-parameter (* 256 1024 1024)))
(define-record-type <audio>
  (%audio rate planes frames)
  audio?
  (rate audio-rate)
  (planes audio-planes)
  (frames audio-frames))

(define (make-audio rate channels frames)
  (ensure (valid-rate? rate) 'rate "invalid audio rate" rate)
  (ensure (exact-integer-in? channels 1 8) 'channels "expected one to eight channels")
  (ensure (and (exact-integer? frames) (>= frames 0)) 'frames "invalid frame count")
  (ensure (<= (* 8 channels frames) (max-buffer-bytes))
          'budget "audio buffer exceeds memory budget" (* 8 channels frames))
  (%audio rate (list->vector (map (lambda (_) (make-f64vector frames 0.0))
                                (iota channels))) frames))

(define (audio-channels a) (vector-length (audio-planes a)))
(define (audio-plane a c) (vector-ref (audio-planes a) c))
(define (audio-ref a c i) (f64vector-ref (audio-plane a c) i))
(define (audio-set! a c i x) (f64vector-set! (audio-plane a c) i (exact->inexact x)))
(define (audio-duration a) (/ (audio-frames a) (audio-rate a)))
(define (audio-bytes a) (* 8 (audio-frames a) (audio-channels a)))

(define (check-region a start end)
  (ensure (and (exact-integer? start) (exact-integer? end)
               (<= 0 start end (audio-frames a)))
          'bounds "audio region is outside the buffer" start end (audio-frames a)))

(define (audio-slice a start end)
  (check-region a start end)
  (let ((out (make-audio (audio-rate a) (audio-channels a) (- end start))))
    (do ((c 0 (+ c 1))) ((= c (audio-channels a)))
      (do ((i start (+ i 1))) ((= i end))
        (audio-set! out c (- i start) (audio-ref a c i))))
    out))
(define (audio-copy a) (audio-slice a 0 (audio-frames a)))

(define (audio-map! a proc)
  (do ((c 0 (+ c 1))) ((= c (audio-channels a)))
    (do ((i 0 (+ i 1))) ((= i (audio-frames a)))
      (audio-set! a c i (proc (audio-ref a c i) c i))))
  a)

(define (audio-clear! a start end)
  (check-region a start end)
  (do ((c 0 (+ c 1))) ((= c (audio-channels a)))
    (do ((i start (+ i 1))) ((= i end)) (audio-set! a c i 0.0)))
  a)

(define (audio-finite? a)
  (call-with-current-continuation
   (lambda (return)
     (audio-map! a (lambda (x c i) (unless (finite-real? x) (return #f)) x))
     #t)))

(define (audio-peak a)
  (let ((peak 0.0))
    (audio-map! a (lambda (x c i) (set! peak (max peak (abs x))) x)) peak))

(define (audio-rms a)
  (let ((sum 0.0) (n (* (audio-frames a) (audio-channels a))))
    (audio-map! a (lambda (x c i) (set! sum (+ sum (* x x))) x))
    (if (zero? n) 0.0 (sqrt (/ sum n)))))

(define (audio-mix! dst src at gain)
  (ensure (and (= (audio-rate dst) (audio-rate src))
               (= (audio-channels dst) (audio-channels src)))
          'format "mix requires matching sample clocks and channels")
  (ensure (finite-real? gain) 'gain "mix gain must be finite")
  (check-region dst at (+ at (audio-frames src)))
  (do ((c 0 (+ c 1))) ((= c (audio-channels src)))
    (do ((i 0 (+ i 1))) ((= i (audio-frames src)))
      (let ((j (+ at i)))
        (audio-set! dst c j (+ (audio-ref dst c j) (* gain (audio-ref src c i)))))))
  dst)
