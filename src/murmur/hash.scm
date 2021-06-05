;;; Incremental SHA-256 for file identity and receipts. Digests detect changes;
;;; they provide neither authenticity nor a signature. No shell subprocesses.
(define-module (murmur hash)
  #:use-module (murmur error)
  #:use-module (murmur binary)
  #:use-module (rnrs bytevectors)
  #:use-module (ice-9 binary-ports)
  #:use-module (srfi srfi-9)
  #:export (make-sha256 sha256-update! sha256-finish! sha256-bytes sha256-file sha256-text))

(define constants
  #(#x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5 #x3956c25b #x59f111f1 #x923f82a4 #xab1c5ed5
    #xd807aa98 #x12835b01 #x243185be #x550c7dc3 #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174
    #xe49b69c1 #xefbe4786 #x0fc19dc6 #x240ca1cc #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
    #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7 #xc6e00bf3 #xd5a79147 #x06ca6351 #x14292967
    #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13 #x650a7354 #x766a0abb #x81c2c92e #x92722c85
    #xa2bfe8a1 #xa81a664b #xc24b8b70 #xc76c51a3 #xd192e819 #xd6990624 #xf40e3585 #x106aa070
    #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5 #x391c0cb3 #x4ed8aa4a #x5b9cca4f #x682e6ff3
    #x748f82ee #x78a5636f #x84c87814 #x8cc70208 #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2))
(define-record-type <sha256>
  (%sha256 words size tail done)
  sha256?
  (words hash-words) (size hash-size hash-size-set!)
  (tail hash-tail hash-tail-set!) (done hash-done? hash-done-set!))
(define (make-sha256)
  (%sha256 (vector #x6a09e667 #xbb67ae85 #x3c6ef372 #xa54ff53a
                   #x510e527f #x9b05688c #x1f83d9ab #x5be0cd19) 0 #vu8() #f))
(define (u32 x) (logand x #xffffffff))
;;; Mask the wrapping low bits before shifting. Every intermediate stays a
;;; 32-bit word, including under compilers that unbox bitwise arithmetic.
(define (rotr x n)
  (logior (ash x (- n))
          (ash (logand x (- (ash 1 n) 1)) (- 32 n))))
(define (big0 x) (logxor (rotr x 2) (rotr x 13) (rotr x 22)))
(define (big1 x) (logxor (rotr x 6) (rotr x 11) (rotr x 25)))
(define (small0 x) (logxor (rotr x 7) (rotr x 18) (ash x -3)))
(define (small1 x) (logxor (rotr x 17) (rotr x 19) (ash x -10)))

(define (compress! state bytes at)
  (let ((w (make-vector 64 0)) (h (hash-words state)))
    (do ((i 0 (+ i 1))) ((= i 16))
      (vector-set! w i (bytevector-u32-ref bytes (+ at (* i 4)) (endianness big))))
    (do ((i 16 (+ i 1))) ((= i 64))
      (vector-set! w i (u32 (+ (small1 (vector-ref w (- i 2)))
                               (vector-ref w (- i 7)) (small0 (vector-ref w (- i 15)))
                               (vector-ref w (- i 16))))))
    (let loop ((i 0) (a (vector-ref h 0)) (b (vector-ref h 1))
               (c (vector-ref h 2)) (d (vector-ref h 3)) (e (vector-ref h 4))
               (f (vector-ref h 5)) (g (vector-ref h 6)) (v (vector-ref h 7)))
      (if (= i 64)
          (let ((result (vector a b c d e f g v)))
            (do ((j 0 (+ j 1))) ((= j 8))
              (vector-set! h j (u32 (+ (vector-ref h j) (vector-ref result j))))))
          (let* ((choose (logxor (logand e f) (logand (lognot e) g)))
                 (majority (logxor (logand a b) (logand a c) (logand b c)))
                 (t1 (u32 (+ v (big1 e) choose (vector-ref constants i) (vector-ref w i))))
                 (t2 (u32 (+ (big0 a) majority))))
            (loop (+ i 1) (u32 (+ t1 t2)) a b c (u32 (+ d t1)) e f g))))))

(define (sha256-update! state bytes)
  (ensure (not (hash-done? state)) 'hash "digest already finalized")
  (let* ((input (bytes-append (hash-tail state) bytes))
         (n (bytevector-length input)) (full (* 64 (quotient n 64))))
    (hash-size-set! state (+ (hash-size state) (bytevector-length bytes)))
    (do ((at 0 (+ at 64))) ((= at full)) (compress! state input at))
    (hash-tail-set! state (bytes-slice input full n))) state)

(define (sha256-finish! state)
  (ensure (not (hash-done? state)) 'hash "digest already finalized")
  (ensure (< (hash-size state) (expt 2 61)) 'hash "message too long")
  (let* ((tail (hash-tail state)) (n (bytevector-length tail))
         (size (if (< n 56) 64 128)) (last (make-bytevector size 0))
         (out (make-bytevector 32 0)))
    (bytevector-copy! tail 0 last 0 n)
    (bytevector-u8-set! last n 128)
    (bytevector-u64-set! last (- size 8) (* 8 (hash-size state)) (endianness big))
    (do ((at 0 (+ at 64))) ((= at size)) (compress! state last at))
    (do ((i 0 (+ i 1))) ((= i 8))
      (bytevector-u32-set! out (* 4 i) (vector-ref (hash-words state) i) (endianness big)))
    (hash-done-set! state #t) (bytes->hex out)))
(define (sha256-bytes bytes)
  (sha256-finish! (sha256-update! (make-sha256) bytes)))
(define (sha256-text text) (sha256-bytes (string->utf8 text)))
(define (sha256-file path)
  (call-with-input-file path
    (lambda (p)
      (let ((state (make-sha256)))
        (let loop ()
          (let ((block (get-bytevector-n p 65536)))
            (if (eof-object? block) (sha256-finish! state)
                (begin (sha256-update! state block) (loop))))))) #:binary #t))
