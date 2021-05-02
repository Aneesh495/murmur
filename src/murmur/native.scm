;;; One platform boundary, for no-replace publication. Audio algorithms remain
;;; ordinary Scheme. The separate timestamp adapter has a small fixed C ABI.
(define-module (murmur native)
  #:use-module (murmur error)
  #:use-module (system foreign)
  #:export (rename-exclusive))
(define (symbol-or-false name)
  (catch #t (lambda () (dynamic-func name (dynamic-link))) (lambda args #f)))
(define exclusive-rename
  (let ((mac (symbol-or-false "renamex_np")) (linux (symbol-or-false "renameat2")))
    (cond
     (mac
      (let ((call (pointer->procedure int mac (list '* '* int))))
        (lambda (a b) (call (string->pointer a) (string->pointer b) 4)))) ; RENAME_EXCL
     (linux
      (let ((call (pointer->procedure int linux (list int '* int '* unsigned-int))))
        (lambda (a b) (call -100 (string->pointer a) -100 (string->pointer b) 1))))
     (else #f))))
(define (rename-exclusive from to)
  (ensure exclusive-rename 'platform "exclusive directory rename unavailable on this platform")
  (ensure (= 0 (exclusive-rename from to)) 'publish "exclusive output publication failed" to))
