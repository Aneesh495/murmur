(use-modules (test) (murmur dsp resample) (murmur buffer))
(test "sinc resampling preserves DC and exact lengths"
  (for-each
   (lambda (rates)
     (let ((a (make-audio (car rates) 1 100)))
       (audio-map! a (lambda (x c i) 0.25))
       (let ((b (resample-audio a (cadr rates))))
         (check-equal (ceiling (/ (* 100 (cadr rates)) (car rates))) (audio-frames b))
         (do ((i 0 (+ i 1))) ((= i (audio-frames b)))
           (check-near 0.25 (audio-ref b 0 i) 1e-12)))))
   '((44100 48000) (48000 8000) (8000 16000) (8000 8000) (44117 48000))))
(test "resampling suppresses aliases"
  (let ((a (make-audio 48000 1 4800)))
    (audio-map! a (lambda (x c i) (sin (* 6.283185307179586 6000 (/ i 48000)))))
    (let* ((b (resample-audio a 8000)) (center (audio-slice b 100 700)))
      (check (< (audio-rms center) 0.0001)))))
(test "low-frequency phase alignment"
  (let* ((r (make-resampler 44100 48000))
         (sample (lambda (i) (sin (* 6.283185307179586 440 (/ i 44100))))))
    (do ((i 0 (+ i 37))) ((> i 2000))
      (check-near (sin (* 6.283185307179586 440 (/ i 48000)))
                  (resampler-ref r sample i) 0.0001))))
