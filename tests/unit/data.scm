(use-modules (test) (murmur data))
(test "data-only grammar and exact decimals"
  (check-equal '(project (rate 48000) (gain -3/2) (label "a\n\"b"))
    (parse-data "; comment\n(project (rate 48000) (gain -1.5) (label \"a\\n\\\"b\"))"))
  (let ((form '(murmur (source "field.wav") (cut 1/3 7/2))))
    (check-equal form (parse-data (data->text form)))))
(test "reader features are rejected"
  (for-each (lambda (s) (check-error 'parse (lambda () (parse-data s))))
            '("#.(system \"oops\")" "'hello" "(a . b)" "#1=(x . #1#)" "(a) (b)"
              "(a" "(a))" "\"bad\\x00;\"" "(1/0)" "(+nan.0)" "(#t)")))
(test "parser resource budgets"
  (check-error 'budget (lambda () (parse-data "((((x))))" #:max-depth 2)))
  (check-error 'budget (lambda () (parse-data "(a b c)" #:max-nodes 3))))
