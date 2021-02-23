(use-modules (test) (murmur dsp envelope))
(test "fades and decibels"
  (check-near 0.5 (db->gain (gain->db 0.5)) 1e-12)
  (check-near 0 (fade-weight 0 100 10 10) 0)
  (check-near 0 (fade-weight 99 100 10 10) 0)
  (check-near 1 (fade-weight 50 100 10 10) 0)
  (check-near 0.5 (fade-weight 5 100 10 10) 0))
(test "mono pan energy and stereo balance"
  (do ((i -10 (+ i 1))) ((> i 10))
    (let* ((g (pan-gains (/ i 10))) (l (car g)) (r (cdr g)))
      (check-near 1 (+ (* l l) (* r r)) 1e-12)))
  (check-near 1 (car (balance-gains 0)) 0)
  (check-near 1 (cdr (balance-gains 0)) 0))
