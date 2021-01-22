(use-modules (test) (fixtures) (murmur wave scan) (murmur binary) (rnrs bytevectors))
(test "RIFF chunk walking"
  (with-bytes
   (fixture-wave (riff-chunk "JUNK" #vu8(1 2 3))
                 (riff-chunk "data" #vu8(0 0 255 127))
                 (riff-chunk "fmt " (fixture-format)))
   (lambda (path)
     (let ((w (scan-wave path)))
       (check-equal 8000 (wave-rate w))
       (check-equal 2 (wave-frames w))
       (check-equal 32 (wave-offset w))))))
(test "ambiguous and malformed RIFF"
  (for-each
   (lambda (chunks)
     (with-bytes (apply fixture-wave chunks)
       (lambda (path) (check-error 'wave (lambda () (scan-wave path))))))
   (list (list (riff-chunk "data" #vu8()))
         (list (riff-chunk "fmt " (fixture-format))
               (riff-chunk "data" #vu8(0)))
         (list (riff-chunk "fmt " (fixture-format))
               (riff-chunk "fmt " (fixture-format)) (riff-chunk "data" #vu8()))
         (list (riff-chunk "fmt " (fixture-format 7)) (riff-chunk "data" #vu8())))))
