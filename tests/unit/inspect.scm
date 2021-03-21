(use-modules (test) (fixtures) (murmur inspect) (murmur buffer) (murmur wave encode) (murmur json))
(test "file analysis measures encoded samples"
  (let ((a (make-audio 8000 1 800)))
    (audio-map! a (lambda (x c i) 0.25))
    (with-bytes (encode-wave a)
      (lambda (path)
        (let ((text (json->text (analyze-wave path #:block-size 137 #:buckets 20))))
          (check (string-contains text "\"rms\":0.25"))
          (check (string-contains (json->text (inspect-wave path)) "\"frames\":800")))))))
