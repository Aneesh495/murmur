;;; Bind an immutable edit document to concrete files and integral frame clocks.
;;; File identity is pinned before rendering and rechecked before publication.
(define-module (murmur project compile)
  #:use-module (murmur error)
  #:use-module (murmur clock)
  #:use-module (murmur paths)
  #:use-module (murmur hash)
  #:use-module (murmur source-hash)
  #:use-module (murmur fingerprint)
  #:use-module (murmur redact)
  #:use-module (murmur wave scan)
  #:use-module (murmur project model)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (compile-project plan? plan-project plan-sources plan-clips plan-frames
            bound-source? bound-id bound-path bound-info bound-masks bound-digest bound-sanitized-digest bound-seed bound-fingerprint
            compiled-clip? compiled-edit compiled-source compiled-start compiled-end
            compiled-at compiled-frames compiled-fade-in compiled-fade-out
            assert-sources-unchanged max-source-bytes max-render-frames))
(define max-source-bytes (make-parameter (* 2 1024 1024 1024)))
(define max-render-frames (make-parameter 200000000))
(define-record-type <bound-source>
  (%bound-source id path info masks digest sanitized seed fingerprint) bound-source?
  (id bound-id) (path bound-path) (info bound-info) (masks bound-masks)
  (digest bound-digest) (sanitized bound-sanitized-digest) (seed bound-seed) (fingerprint bound-fingerprint))
(define-record-type <compiled-clip>
  (%compiled-clip edit source start end at frames fade-in fade-out) compiled-clip?
  (edit compiled-edit) (source compiled-source) (start compiled-start) (end compiled-end)
  (at compiled-at) (frames compiled-frames) (fade-in compiled-fade-in) (fade-out compiled-fade-out))
(define-record-type <plan>
  (%plan project sources clips frames) plan?
  (project plan-project) (sources plan-sources) (clips plan-clips) (frames plan-frames))

(define (compile-project project document)
  (let* ((paths (map (lambda (s) (resolve-source document (source-path s))) (project-sources project)))
         (total (fold (lambda (p n) (+ n (stat:size (stat p)))) 0 paths)))
    (ensure (<= total (max-source-bytes)) 'budget "source files exceed session budget" total)
    (ensure (= (length paths) (length (delete-duplicates paths)))
            'source "one file cannot appear under multiple source identifiers")
    (let* ((sources
            (map
             (lambda (s path)
               (let* ((fingerprint (file-fingerprint path)) (info (scan-wave path)) (digest (sha256-file path))
                      (redactions (filter (lambda (r) (eq? (redaction-source r) (source-id s)))
                                          (project-redactions project))))
                 (when (source-digest s)
                   (ensure (string=? digest (source-digest s)) 'source "pinned source digest mismatch" (source-id s)))
                 (let* ((masks (compile-masks redactions info))
                        (seed (source-noise-seed (project-seed project) (source-id s)))
                        (sanitized (sanitized-source-digest path info masks seed)))
                   (ensure (equal? fingerprint (file-fingerprint path))
                           'source "source changed while binding the edit plan" (source-id s))
                   (%bound-source (source-id s) path info masks digest sanitized seed fingerprint))))
             (project-sources project) paths))
           (rate (project-rate project))
           (clips
            (map
             (lambda (edit)
               (let* ((source (find (lambda (s) (eq? (bound-id s) (clip-source edit))) sources))
                      (native-rate (wave-rate (bound-info source)))
                      (start (seconds->frame (clip-from edit) native-rate))
                      (end (seconds->frame (clip-to edit) native-rate))
                      (frames (duration-frames (- end start) native-rate rate))
                      (at (seconds->frame (clip-at edit) rate))
                      (fi (seconds->frame (clip-fade-in edit) rate))
                      (fo (seconds->frame (clip-fade-out edit) rate)))
                 (ensure (<= 0 start end (wave-frames (bound-info source)))
                         'clip "clip extends past source" (clip-id edit))
                 (ensure (> frames 0) 'clip "clip rounds to zero frames" (clip-id edit))
                 (ensure (<= (+ fi fo) frames) 'clip "rounded fades overlap" (clip-id edit))
                 (%compiled-clip edit source start end at frames fi fo))) (project-clips project)))
           (frames (fold (lambda (c n) (max n (+ (compiled-at c) (compiled-frames c)))) 0 clips)))
      (ensure (<= frames (max-render-frames)) 'budget "output exceeds frame budget" frames)
      (ensure (<= (fold (lambda (c n) (+ n (compiled-frames c))) 0 clips)
                  (* 8 (max-render-frames))) 'budget "overlap work exceeds frame budget")
      (ensure (= (length sources) (length (delete-duplicates (map bound-digest sources))))
              'source "identical source bytes must share one source identifier")
      (for-each (lambda (m) (ensure (<= (seconds->frame (car m) rate) frames)
                                   'marker "marker is past the output end")) (project-markers project))
      (%plan project sources clips frames))))
(define (assert-sources-unchanged plan)
  (for-each
   (lambda (s)
     (ensure (and (equal? (bound-fingerprint s) (file-fingerprint (bound-path s)))
                  (string=? (bound-digest s) (sha256-file (bound-path s)))
                  (equal? (bound-fingerprint s) (file-fingerprint (bound-path s))))
             'source "source changed during rendering" (bound-id s)))
   (plan-sources plan)))
