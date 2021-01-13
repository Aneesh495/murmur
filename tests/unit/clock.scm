(use-modules (test) (murmur clock))
(test "exact decimal clocks"
  (check-equal 1/10 (parse-time "0.1"))
  (check-equal 62003/1000 (parse-time "01:02.003"))
  (check-equal 3723 (parse-time "1:02:03"))
  (check-equal 1 (seconds->frame 1/16000 8000))
  (check-equal 0 (floor-frame 1/16000 8000))
  (check-equal 1 (ceiling-frame 1/16000 8000))
  (check-equal 48000 (duration-frames 44100 44100 48000))
  (check-equal "01:02.003" (format-time 62003/1000)))
(test "invalid clocks"
  (for-each (lambda (x) (check-error 'time (lambda () (parse-time x))))
            '("" "1..2" ".2" "1." "1:60" "-1" "1e3" 0.1 -1 +nan.0))
  (check-error 'rate (lambda () (seconds->frame 1 0))))
(test "clock round trips"
  (for-each
   (lambda (rate)
     (do ((i 0 (+ i 37))) ((>= i 5000))
       (check-equal i (seconds->frame (frame->seconds i rate) rate))))
   '(8000 11025 44100 48000 96000)))
