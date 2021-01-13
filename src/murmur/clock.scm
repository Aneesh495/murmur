;;; Exact clocks prevent a decimal timestamp from drifting across edit edges.
;;; All intervals are half open. A forbidden source interval expands outwards.
(define-module (murmur clock)
  #:use-module (murmur error)
  #:use-module (srfi srfi-13)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:export (parse-time seconds->frame floor-frame ceiling-frame frame->seconds
            valid-rate? duration-frames format-time))

(define (valid-rate? rate) (exact-integer-in? rate 1 384000))

(define (decimal text)
  (ensure (and (string? text) (<= 1 (string-length text) 40))
          'time "expected a decimal timestamp")
  (let ((parts (string-split text #\.)))
    (ensure (and (<= (length parts) 2)
                 (every-digit? (car parts))
                 (or (= 1 (length parts)) (every-digit? (cadr parts))))
            'time "invalid decimal timestamp" text)
    (if (= 1 (length parts))
        (string->number text)
        (+ (string->number (car parts))
           (/ (string->number (cadr parts))
              (expt 10 (string-length (cadr parts))))))))

(define (every-digit? text)
  (and (positive? (string-length text))
       (string-every (lambda (c) (char<=? #\0 c #\9)) text)))

(define (parse-time value)
  (cond
   ((and (rational? value) (exact? value) (<= 0 value 86400)) value)
   ((string? value)
    (let* ((parts (string-split value #\:))
           (values (map decimal parts)))
      (ensure (<= 1 (length parts) 3) 'time "use seconds, mm:ss, or hh:mm:ss")
      (when (> (length values) 1)
        (ensure (every (lambda (v) (< v 60)) (cdr values))
                'time "minutes and seconds must be below 60")
        (ensure (every exact-integer? (drop-right values 1))
                'time "only seconds may contain a fraction"))
      (parse-time (fold (lambda (v acc) (+ (* acc 60) v)) 0 values))))
   (else (fail 'time "timestamp must be exact and between zero and one day" value))))

;;; The default tie rule is explicit: nearest frame, ties toward the future.
(define (seconds->frame seconds rate)
  (ensure (valid-rate? rate) 'rate "invalid sample rate" rate)
  (inexact->exact (floor (+ (* (parse-time seconds) rate) 1/2))))

(define (floor-frame seconds rate)
  (ensure (valid-rate? rate) 'rate "invalid sample rate" rate)
  (inexact->exact (floor (* (parse-time seconds) rate))))

(define (ceiling-frame seconds rate)
  (ensure (valid-rate? rate) 'rate "invalid sample rate" rate)
  (inexact->exact (ceiling (* (parse-time seconds) rate))))

(define (frame->seconds frame rate)
  (ensure (and (exact-integer? frame) (>= frame 0) (valid-rate? rate))
          'time "invalid frame clock" frame rate)
  (/ frame rate))

(define (duration-frames frames from-rate to-rate)
  (ensure (and (exact-integer? frames) (>= frames 0)
               (valid-rate? from-rate) (valid-rate? to-rate))
          'time "invalid resampling clock")
  (ceiling (/ (* frames to-rate) from-rate)))

(define (format-time seconds)
  (let* ((ms (seconds->frame seconds 1000))
         (minutes (quotient ms 60000))
         (rest (modulo ms 60000)))
    (format #f "~2,'0d:~2,'0d.~3,'0d" minutes (quotient rest 1000) (modulo rest 1000))))
