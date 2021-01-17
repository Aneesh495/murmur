(use-modules (test) (murmur interval))
(test "canonical intervals"
  (check-equal '((1 . 9)) (spans-normalize '((4 . 9) (1 . 3) (3 . 4) (5 . 5))))
  (check-equal '((0 . 2) (4 . 5) (8 . 10))
               (spans-subtract '((0 . 10)) '((2 . 4) (5 . 8))))
  (check-equal '((2 . 4)) (spans-intersect '((0 . 4)) '((2 . 8))))
  (check-equal '((0 . 1) (9 . 10)) (spans-complement '((1 . 9)) 10))
  (check-equal '((0 . 6)) (spans-expand '((2 . 4)) 2 6))
  (check (not (span-contains? (span 1 2) 2)))
  (check-error 'interval (lambda () (span 3 2))))
(test "interval algebra against point sets"
  (let ((sets '(() ((0 . 2)) ((2 . 5)) ((0 . 1) (3 . 7)) ((1 . 5) (4 . 8)))))
    (for-each
     (lambda (a)
       (for-each
        (lambda (b)
          (do ((p 0 (+ p 1/2))) ((>= p 10))
            (let ((pa (if (spans-member? a p) #t #f))
                  (pb (if (spans-member? b p) #t #f)))
              (check-equal (and pa pb) (if (spans-member? (spans-intersect a b) p) #t #f))
              (check-equal (and pa (not pb)) (if (spans-member? (spans-subtract a b) p) #t #f))
              (check-equal (or pa pb) (if (spans-member? (spans-union a b) p) #t #f)))))
        sets)) sets)))
