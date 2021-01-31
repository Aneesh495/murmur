(use-modules (test) (murmur hash) (murmur binary) (rnrs bytevectors) (fixtures))
(test "SHA-256 known answers"
  (check-equal "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
               (sha256-text ""))
  (check-equal "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
               (sha256-text "abc"))
  (check-equal "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
               (sha256-text "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")))
(test "hash chunk boundaries"
  (do ((size 0 (+ size 1))) ((= size 140))
    (let* ((b (make-bytevector size 97)) (expected (sha256-bytes b)))
      (do ((split 0 (+ split 13))) ((> split size))
        (let ((h (make-sha256)))
          (sha256-update! h (bytes-slice b 0 split))
          (sha256-update! h (bytes-slice b split size))
          (check-equal expected (sha256-finish! h))
          (check-error 'hash (lambda () (sha256-update! h b))))))
    (when (= size 70)
      (with-bytes (make-bytevector size 97)
        (lambda (path) (check-equal (sha256-bytes (make-bytevector size 97))
                                    (sha256-file path)))))))
