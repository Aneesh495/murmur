(use-modules (test) (murmur dsp stft) (murmur buffer))
(test "weighted overlap-add reconstructs boundaries"
  (for-each
   (lambda (frames)
     (let ((a (make-audio 8000 2 frames)))
       (audio-map! a (lambda (x c i) (+ (* 0.3 (sin (+ i c))) (if (= i 0) 0.5 0))))
       (let ((b (stft-process a 64 16 (lambda args #t))))
         (do ((c 0 (+ c 1))) ((= c 2))
           (do ((i 0 (+ i 1))) ((= i frames))
             (check-near (audio-ref a c i) (audio-ref b c i) 1e-12))))))
   '(0 1 7 31 64 65 257)))
(test "noise profiles need complete windows"
  (check-error 'profile (lambda () (spectral-profile (make-audio 8000 1 100) 0 30 64 16))))
