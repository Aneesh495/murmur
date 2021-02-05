(use-modules (test) (murmur json))
(test "JSON types and script-safe strings"
  (check-equal "{\"a\":[],\"b\":{},\"c\":null,\"d\":true}\n"
    (json->text (object (cons 'a '()) (cons 'b (object))
                       (cons 'c json-null) (cons 'd #t))))
  (check-equal "\"\\u003c/script\\u003e\\n\\\"\"\n"
               (json->text "</script>\n\""))
  (check-equal "0.5\n" (json->text 1/2))
  (check-error 'json (lambda () (json->text +inf.0))))
