(use-modules (murmur cli))
; Deliver cancellation as a Scheme exception so dynamic-wind closes ports and
; removes the newly owned staging directory before the process exits.
(sigaction SIGINT (lambda (signal) (throw 'murmur-cancel signal)))
(sigaction SIGTERM (lambda (signal) (throw 'murmur-cancel signal)))
(exit (main (command-line)))
