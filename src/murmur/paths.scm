;;; Source paths resolve relative to the document, never relative to whichever
;;; directory happened to launch the command. Output destinations are new trees.
(define-module (murmur paths)
  #:use-module (murmur error)
  #:use-module (murmur schema)
  #:use-module (ice-9 ftw)
  #:use-module (srfi srfi-1)
  #:export (resolve-source absolute-output exists-any? remove-private-tree mkdir-new
            with-staging-directory publish-directory))

(define (exists-any? path)
  (catch 'system-error (lambda () (lstat path) #t)
    (lambda args
      (let ((code (system-error-errno args)))
        (if (= code ENOENT) #f (apply throw args))))))
(define (resolve-source document path)
  (ensure (path-value? path) 'path "invalid source path")
  (let ((resolved (canonicalize-path
                   (if (absolute-file-name? path) path
                       (string-append (dirname (canonicalize-path document)) "/" path)))))
    (ensure (eq? 'regular (stat:type (stat resolved))) 'path "source must be a regular file")
    resolved))
(define (absolute-output path)
  (ensure (path-value? path) 'path "invalid output path")
  (let ((leaf (basename path)))
    (ensure (not (member leaf '("." ".." "/"))) 'path "output needs a new directory name")
    (string-append (canonicalize-path (dirname path)) "/" leaf)))
(define (mkdir-new path)
  (ensure (not (exists-any? path)) 'exists "destination already exists" path)
  (mkdir path #o700))
(define (remove-private-tree root)
  ;; Never call this on a user-selected tree. The sole caller owns mkdtemp's
  ;; newly created directory, and lstat avoids following links during cleanup.
  (when (exists-any? root)
    (if (eq? (stat:type (lstat root)) 'directory)
        (begin
          (for-each (lambda (name) (remove-private-tree (string-append root "/" name)))
                    (scandir root (lambda (x) (not (member x '("." ".."))))))
          (rmdir root))
        (delete-file root))))
(define (publish-directory stage destination)
  ;; Implemented through libc's exclusive rename primitive. A check followed
  ;; by ordinary rename could replace a directory that appeared in between.
  ((module-ref (resolve-interface '(murmur native)) 'rename-exclusive) stage destination))
(define (with-staging-directory destination proc)
  (let* ((target (absolute-output destination))
         (_ (ensure (not (exists-any? target)) 'exists "destination already exists" target))
         (stage (mkdtemp (string-append (dirname target) "/.murmur-XXXXXX")))
         (published #f))
    (chmod stage #o700)
    (dynamic-wind
      (lambda () #t)
      (lambda ()
        (let ((result (proc stage)))
          (publish-directory stage target)
          (set! published #t) result))
      (lambda () (unless published (remove-private-tree stage))))))
