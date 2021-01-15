;;; Canonical half-open intervals. Adjacent spans merge because they leave no
;;; safe sample between them. Empty spans disappear during normalization.
(define-module (murmur interval)
  #:use-module (murmur error)
  #:use-module (srfi srfi-1)
  #:export (span span-start span-end span-length span-empty? span-contains?
            span-intersect spans-normalize spans-union spans-intersect
            spans-subtract spans-complement spans-measure spans-member?
            spans-clip spans-expand))

(define (span start end)
  (ensure (and (finite-real? start) (finite-real? end) (<= 0 start end))
          'interval "invalid half-open interval" start end)
  (cons start end))
(define span-start car)
(define span-end cdr)
(define (span-length s) (- (cdr s) (car s)))
(define (span-empty? s) (= (car s) (cdr s)))
(define (span-contains? s point)
  (and (<= (car s) point) (< point (cdr s))))

(define (span-intersect a b)
  (let ((lo (max (car a) (car b))) (hi (min (cdr a) (cdr b))))
    (and (< lo hi) (span lo hi))))

(define (spans-normalize spans)
  (let loop ((rest (sort (filter (lambda (s) (not (span-empty? s))) spans)
                          (lambda (a b) (< (car a) (car b)))))
             (out '()))
    (cond
     ((null? rest) (reverse out))
     ((and (pair? out) (<= (caar rest) (cdar out)))
      (loop (cdr rest) (cons (span (caar out) (max (cdar out) (cdar rest))) (cdr out))))
     (else (loop (cdr rest) (cons (car rest) out))))))

(define (spans-union a b) (spans-normalize (append a b)))

(define (spans-intersect a b)
  (let loop ((a (spans-normalize a)) (b (spans-normalize b)) (out '()))
    (if (or (null? a) (null? b)) (reverse out)
        (let ((hit (span-intersect (car a) (car b))))
          (if (< (cdar a) (cdar b))
              (loop (cdr a) b (if hit (cons hit out) out))
              (loop a (cdr b) (if hit (cons hit out) out)))))))

(define (spans-subtract a b)
  (let ((cuts (spans-normalize b)))
    (append-map
     (lambda (s)
       (let loop ((cursor (car s)) (rest cuts) (out '()))
         (cond
          ((>= cursor (cdr s)) (reverse out))
          ((or (null? rest) (>= (caar rest) (cdr s)))
           (reverse (cons (span cursor (cdr s)) out)))
          ((<= (cdar rest) cursor) (loop cursor (cdr rest) out))
          (else
           (loop (min (cdr s) (cdar rest)) (cdr rest)
                 (if (< cursor (caar rest))
                     (cons (span cursor (caar rest)) out) out))))))
     (spans-normalize a))))

(define (spans-complement spans length)
  (spans-subtract (list (span 0 length)) spans))
(define (spans-measure spans)
  (fold (lambda (s total) (+ total (span-length s))) 0 (spans-normalize spans)))
(define (spans-member? spans point)
  (any (lambda (s) (span-contains? s point)) spans))
(define (spans-clip spans bound)
  (spans-intersect spans (list bound)))
(define (spans-expand spans guard length)
  (ensure (and (finite-real? guard) (>= guard 0)) 'interval "negative guard")
  (spans-normalize
   (map (lambda (s) (span (max 0 (- (car s) guard))
                         (min length (+ (cdr s) guard))))
        (spans-clip spans (span 0 length)))))
