(define-module (murmur cli)
  #:use-module (murmur error)
  #:use-module (murmur data)
  #:use-module (murmur schema)
  #:use-module (murmur json)
  #:use-module (murmur new)
  #:use-module (murmur render)
  #:use-module (murmur inspect)
  #:use-module (murmur bundle)
  #:use-module (murmur patch)
  #:use-module (murmur labels)
  #:use-module (murmur provenance)
  #:use-module (murmur project parse)
  #:use-module (murmur project compile)
  #:use-module (murmur project model)
  #:use-module (murmur effects)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:export (main))
(define usage
  "murmur 0.1.0 / offline recording repair and source redaction

  murmur init INPUT.wav EDIT.mur
  murmur render EDIT.mur NEW_BUNDLE [--block-size N] [--bits 16|24|32|64]
                                  [--float] [--no-dither]
  murmur inspect INPUT.wav
  murmur analyze INPUT.wav
  murmur plan EDIT.mur
  murmur explain EDIT.mur FRAME
  murmur verify BUNDLE
  murmur labels EDIT.mur SOURCE LABELS.tsv [mute|tone|noise]
  murmur apply-patch EDIT.mur PATCH.mur NEW_EDIT.mur
  murmur demo NEW_DIRECTORY
  murmur doctor
  murmur version

Render refuses existing destinations and audio above full scale.
Use an explicit limit effect to control peaks. Paths are relative to EDIT.mur.
")
(define (arity args n)
  (ensure (= (length args) n) 'usage "incorrect command arguments; run murmur help"))
(define (integer-argument text)
  (let ((value (string->number text)))
    (ensure (exact-integer? value) 'usage "expected an integer argument" text) value))
(define (checked-plan document)
  (let* ((plan (compile-project (read-project document) document)) (p (plan-project plan)))
    (compile-effects (project-effects p) (project-rate p) (plan-frames plan)) plan))
(define (render-command args)
  (ensure (>= (length args) 2) 'usage "render requires a project and a new bundle directory")
  (let loop ((rest (drop args 2)) (block-size 4096) (bits #f) (format 1) (dither #t) (seen '()))
    (if (null? rest)
        (begin
          (render-project (car args) (cadr args) #:block-size block-size #:bits (or bits (if (= format 3) 32 16)) #:sample-format format #:dither dither)
          (display (json->text (verify-bundle (cadr args)))))
        (let ((key (car rest)))
          (ensure (not (member key seen)) 'usage "duplicate render option" key)
          (cond
           ((or (string=? key "--block-size") (string=? key "--bits"))
            (ensure (pair? (cdr rest)) 'usage "render option needs a value" key)
            (let ((v (integer-argument (cadr rest))))
              (loop (cddr rest) (if (string=? key "--block-size") v block-size)
                    (if (string=? key "--bits") v bits) format dither (cons key seen))))
           ((string=? key "--float") (loop (cdr rest) block-size bits 3 dither (cons key seen)))
           ((string=? key "--no-dither") (loop (cdr rest) block-size bits format #f (cons key seen)))
           (else (fail 'usage "unknown render option" key)))))))
(define (dispatch command args)
  (cond
   ((member command '("help" "--help" "-h")) (display usage))
   ((member command '("version" "--version")) (arity args 0) (display "murmur 0.1.0\n"))
   ((string=? command "doctor")
    (arity args 0)
    (display (json->text (object (cons 'guile (version)) (cons 'host %host-type)
                                 (cons 'required "Guile 3.0, macOS or Linux")
                                 (cons 'network "not required") (cons 'audioDevice "not required")))))
   ((string=? command "init") (arity args 2) (init-project (car args) (cadr args)) (display (string-append (cadr args) "\n")))
   ((string=? command "render") (render-command args))
   ((string=? command "inspect") (arity args 1) (display (json->text (inspect-wave (car args)))))
   ((string=? command "analyze") (arity args 1) (display (json->text (analyze-wave (car args)))))
   ((string=? command "plan") (arity args 1) (display (json->text (plan->json (checked-plan (car args))))))
   ((string=? command "explain") (arity args 2) (display (json->text (explain-frame (checked-plan (car args)) (integer-argument (cadr args))))))
   ((string=? command "verify") (arity args 1) (display (json->text (verify-bundle (car args)))))
   ((string=? command "labels")
    (ensure (<= 3 (length args) 4) 'usage "labels requires project, source, and label file")
    (let ((source (parse-data (cadr args))) (mode (if (= 4 (length args)) (parse-data (cadddr args)) 'mute)))
      (display (data->text (labels->patch (car args) source (caddr args) mode)))))
   ((string=? command "apply-patch") (arity args 3)
    (apply-source-patch (car args) (cadr args) (caddr args)) (display (string-append (caddr args) "\n")))
   ((string=? command "demo")
    (arity args 1)
    ((module-ref (resolve-interface '(murmur demo)) 'make-demo) (car args)))
   (else (fail 'usage "unknown command; run murmur help" command))))
(define (main argv)
  (catch #t
    (lambda ()
      (if (null? (cdr argv)) (display usage) (dispatch (cadr argv) (cddr argv))) 0)
    (lambda (key . args)
      (cond
       ((eq? key 'murmur-cancel)
        (format (current-error-port) "murmur: interrupted by signal ~a~%" (car args))
        (+ 128 (car args)))
       ((eq? key 'murmur)
        (format (current-error-port) "murmur: ~a: ~a~{ ~s~}~%" (car args) (cadr args) (caddr args))
        (if (eq? (car args) 'usage) 2 1))
       ((eq? key 'system-error)
        (format (current-error-port) "murmur: io: ~a~%" (strerror (system-error-errno (cons key args)))) 1)
       (else
        (format (current-error-port) "murmur: internal: ~s ~s~%" key args) 70)))))
