;;; Review embeds only the sanitized output's analysis, edit map, and identities.
;;; The browser never sees source audio or source paths. Assets are inlined for
;;; file:// use, with no server, fonts, CDNs, fetch calls, or telemetry.
(define-module (murmur review)
  #:use-module (murmur error)
  #:use-module (murmur json)
  #:use-module (murmur provenance)
  #:use-module (murmur bundle)
  #:use-module (ice-9 textual-ports)
  #:export (write-review))
(define (asset name)
  (let ((path (search-path %load-path (string-append "murmur/assets/" name))))
    (ensure path 'install "review asset is missing" name)
    (call-with-input-file path get-string-all #:encoding "UTF-8")))
(define (write-review stage plan analysis)
  (let ((data (json->text (object (cons 'plan (plan->json plan)) (cons 'planSha256 (plan-digest plan))
                                 (cons 'sources (source-identities plan)) (cons 'analysis analysis)))))
    (write-text (string-append stage "/review.html")
      (string-append (asset "header.html") "<style>" (asset "review.css") "</style></head><body>"
                     (asset "body.html") "<script id=review-data type=application/json>" data
                     "</script><script>" (asset "review.js") "</script></body></html>"))))
