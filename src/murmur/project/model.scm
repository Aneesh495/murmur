;;; The parser constructs immutable records. A compiled plan is a separate
;;; representation, preventing file metadata from mutating the user's edits.
(define-module (murmur project model)
  #:use-module (srfi srfi-9)
  #:export (make-source source? source-id source-path source-digest
            make-redaction redaction? redaction-source redaction-from redaction-to
            redaction-mode redaction-guard redaction-level redaction-frequency
            make-clip clip? clip-id clip-source clip-from clip-to clip-at clip-gain
            clip-pan clip-fade-in clip-fade-out
            make-project project? project-rate project-channels project-seed
            project-sources project-redactions project-clips project-effects project-markers))
(define-record-type <source>
  (make-source id path digest) source?
  (id source-id) (path source-path) (digest source-digest))
(define-record-type <redaction>
  (make-redaction source from to mode guard level frequency) redaction?
  (source redaction-source) (from redaction-from) (to redaction-to)
  (mode redaction-mode) (guard redaction-guard) (level redaction-level)
  (frequency redaction-frequency))
(define-record-type <clip>
  (make-clip id source from to at gain pan fade-in fade-out) clip?
  (id clip-id) (source clip-source) (from clip-from) (to clip-to) (at clip-at)
  (gain clip-gain) (pan clip-pan) (fade-in clip-fade-in) (fade-out clip-fade-out))
(define-record-type <project>
  (make-project rate channels seed sources redactions clips effects markers) project?
  (rate project-rate) (channels project-channels) (seed project-seed)
  (sources project-sources) (redactions project-redactions) (clips project-clips)
  (effects project-effects) (markers project-markers))
