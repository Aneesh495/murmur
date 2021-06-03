(define-module (test)
  #:use-module (murmur error)
  #:use-module (ice-9 format)
  #:export (test check check-equal check-near check-error finish-tests))

(define assertions 0)
(define cases 0)
(define failures '())

(define-syntax-rule (test name body ...)
  (begin
    (set! cases (+ cases 1))
    (catch #t
      (lambda () body ...)
      (lambda args
        (set! failures (cons (cons name args) failures))
        (format (current-error-port) "FAIL ~a: ~s~%" name args)))))

(define (check value)
  (set! assertions (+ assertions 1))
  (unless value (error "assertion failed")))

(define (check-equal expected actual)
  (set! assertions (+ assertions 1))
  (unless (equal? expected actual)
    (error "values differ" expected actual)))

(define (check-near expected actual tolerance)
  (set! assertions (+ assertions 1))
  (unless (and (finite-real? actual) (<= (abs (- expected actual)) tolerance))
    (error "numeric values differ" expected actual tolerance)))

(define (check-error code thunk)
  (set! assertions (+ assertions 1))
  (let ((observed
         (catch 'murmur
           (lambda () (thunk) #f)
           (lambda (key actual message context) actual))))
    (unless (eq? code observed) (error "wrong error" code observed))))

(define (finish-tests)
  (unless (file-exists? "build") (mkdir "build"))
  (call-with-output-file (or (getenv "MURMUR_TEST_REPORT") "build/scheme-tests.json")
    (lambda (p) (format p "{\"cases\":~a,\"assertions\":~a,\"failures\":~a}~%"
                        cases assertions (length failures))))
  (format #t "~a cases, ~a assertions, ~a failures~%"
          cases assertions (length failures))
  (exit (if (null? failures) 0 1)))
