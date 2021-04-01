(use-modules (test) (murmur labels) (murmur data))
(test "label import discards transcript text"
  (let ((edits (parse-labels "0.25\t0.5\tprivate phrase\n\n# comment\n1\t2\tname\n" 'field 'mute)))
    (check-equal '((redact field (from 1/4) (to 1/2) (mode mute))
                   (redact field (from 1) (to 2) (mode mute))) edits)
    (check (not (string-contains (data->text edits) "private")))))
(test "labels require real intervals"
  (check-error 'labels (lambda () (parse-labels "1\t1\tpoint" 'field 'mute)))
  (check-error 'labels (lambda () (parse-labels "0.5 1.0 words" 'field 'mute))))
