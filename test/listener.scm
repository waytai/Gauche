;;
;; test for listener
;; $Id: listener.scm,v 1.2 2003-01-08 00:53:53 shirok Exp $

(use gauche.test)

(test-start "listener")

(use gauche.listener)

(test-section "complete-sexp?")

(define-syntax sexp-tester
  (syntax-rules ()
    ((_ result str)
     (test* (format #f "complete-sexp? ~,,,,40:a" str)
            result
            (complete-sexp? str)))
    ))

(sexp-tester #t "")
(sexp-tester #t "a")
(sexp-tester #t "abc")
(sexp-tester #t "123")
(sexp-tester #t "  3/4  ")
(sexp-tester #t "  3/4")
(sexp-tester #t "()")
(sexp-tester #t "(abc)")
(sexp-tester #t " ( a ) ")
(sexp-tester #t " (a) ")
(sexp-tester #t "(a . b)")
(sexp-tester #t " ((((a)))) ")
(sexp-tester #f " ((((a))) ")
(sexp-tester #f " (((( a ))) ")
(sexp-tester #t "(ab cd ef (guhr janr) ((airugn jenr) (bjn unrg)) () )")
(sexp-tester #t "(ab cd ef [guhr janr] {[airugn jenr] (bjn unrg)} () )")
(sexp-tester #f "(ab cd ef [guhr janr] {[airugn jenr} (bjn unrg)] () )")
(sexp-tester #t " \"rugier\"")
(sexp-tester #t " \"rugi \\\"er\\\" unga\"")
(sexp-tester #t " \"\\\"\\\"\"")
(sexp-tester #f " \"\\\"er\\\"")
(sexp-tester #t " \"\\\"er\"")
(sexp-tester #t " \"\\\"(\"")
(sexp-tester #t "#\\a")
(sexp-tester #f "#\\")
(sexp-tester #t "#\\abunaga")
(sexp-tester #t "#\\abunaga'(boogaz)")
(sexp-tester #f "#\\abunaga'(boogaz")
(sexp-tester #t "#\\(")
(sexp-tester #t "(#\\( )")
(sexp-tester #t "(#\\(gunar)")
(sexp-tester #t "(#\\(gunar)")
(sexp-tester #t "#(bunga bunga)")
(sexp-tester #t "[#(bunga bunga)]")
(sexp-tester #t "#x#d3242(bunar)")
(sexp-tester #t "|buna(-|")
(sexp-tester #f "|buna(-")
(sexp-tester #t "|buna(-\\|zuppe|")
(sexp-tester #t "|buna(-\\|zu[p\"e|")
(sexp-tester #t "(|buna(-| . a)")
(sexp-tester #t "#,(bunga bunga bunga)")
(sexp-tester #t "#,()")
(sexp-tester #f "#,(yop")
(sexp-tester #t "(#,( () ) . a)")
(sexp-tester #t "#[a-z]")
(sexp-tester #t "#[[:alpha:]]")
(sexp-tester #t "#[\\]]")
(sexp-tester #f "#[1234")
(sexp-tester #f "(#[1234 . )")
(sexp-tester #t "(#[1234] . a)")
(sexp-tester #t "[#[1234] . a]")
(sexp-tester #t "#/reg(exp)fofofo[\\s\\d]/")
(sexp-tester #t "#/(/")
(sexp-tester #t "#/\\(/")
(sexp-tester #t "#/\\/usr\\/bin/")
(sexp-tester #f "#/\\/usr\\/bin  ")
(sexp-tester #t "(#/(/ . a)")
(sexp-tester *test-error* "(ibanr #<booba> )")

(test-section "listener")

(define-values (ipipe-in ipipe-out) (sys-pipe))
(define-values (opipe-in opipe-out) (sys-pipe))
(define-values (epipe-in epipe-out) (sys-pipe))

(set! (port-buffering ipipe-in) :none)
(set! (port-buffering ipipe-out) :none)
(set! (port-buffering opipe-in) :none)
(set! (port-buffering opipe-out) :none)

(define listener
  (make <listener>
    :input-port ipipe-in
    :output-port opipe-out
    :error-port epipe-out
    :prompter (lambda () (display "<<<\n"))))

(define handler (listener-read-handler listener))

(test* "prompter" "<<<"
       (begin
         (listener-show-prompt listener)
         (read-line opipe-in)))

(define (send-expr expr)
  (display expr ipipe-out) (flush ipipe-out))

(define (read-results)
  (let loop ((l (read-line opipe-in))
             (r '()))
    (if (equal? l "<<<")
        (reverse r)
        (loop (read-line opipe-in) (cons l r)))))

(test* "listener" '("3")
       (begin
         (send-expr "(+ 1 2)\n")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (read-results)))

(test* "listener" '("1" "2" "3")
       (begin
         (send-expr "(values 1 2 3)\n")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (read-results)))

(test* "listener" '(("1") ("2"))
       (begin
         (send-expr "1 2\n")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (let* ((r0 (read-results))
                (r1 (read-results)))
           (list r0 r1))))

(test* "listener" '("3")
       (begin
         (send-expr "(+ 1 \n")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (send-expr "2")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (send-expr ")")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (read-results)))

(test* "listener" '(("#\\a") ("3"))
       (begin
         (send-expr "#\\")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (send-expr "a (+")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (send-expr " 1 2)")
         (with-error-handler (lambda (e) (print (ref e 'message)))
           handler)
         (let* ((r0 (read-results))
                (r1 (read-results)))
           (list r0 r1))))

;(test "listener (error)" "error"
;      (lambda ()
;        (send-expr "zzz")
;        (with-error-handler (lambda (e)
;                              (print "error" (currnet-error-port)))
;                            handler)
;        (read-line epipe-in)))

;(test "listener" #t
;      (lambda ()
;        (send-expr "(+ 1 2 ")
;        (handler)
;        (close-output-port ipipe-out)
;        (handler)
;        ))

(test-end)
