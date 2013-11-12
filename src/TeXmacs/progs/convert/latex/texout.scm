
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : texout.scm
;; DESCRIPTION : generation of TeX/LaTeX from scheme expressions
;; COPYRIGHT   : (C) 2002  Joris van der Hoeven
;;
;; This software falls under the GNU general public license version 3 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (convert latex texout)
  (:use (convert latex latex-tools)
	(convert tools output)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interface for unicode output
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (output-tex s)
  (output-text (if tmtex-use-ascii? (string-convert s "UTF-8" "LaTeX") s)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Outputting preamble and postamble
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (collection->ahash-table init)
  (let* ((t (make-ahash-table))
	 (l (if (func? init 'collection) (cdr init) '()))
	 (f (lambda (x) (ahash-set! t (cadr x) (caddr x)))))
    (for-each f l)
    t))

(define (drop-blank s)
  (string-replace s " " ""))

(define (latex-stree-contains? t u)
  (cond ((== t u) #t)
        ((and (string? t) (string? u)) (string-contains? t (drop-blank u)))
        ((nlist? t) #f)
        ((null? t) #f)
        (else (or (latex-stree-contains? (car t) u)
                  (in? #t (map (lambda (x)
                                 (latex-stree-contains? x u)) (cdr t)))))))

(define (texout-file l)
  (let* ((doc-body (car l))
         (has-preamble? (latex-stree-contains? doc-body "\\begin{document}"))
         (has-end?      (latex-stree-contains? doc-body "\\end{document}"))
	 (styles (if (null? (cadr l)) (list "article") (cadr l)))
	 (style (car styles))
	 (prelan (caddr l))
	 (lan (if (== prelan "") "english" prelan))
	 (init (collection->ahash-table (cadddr l)))
	 (doc-preamble (car (cddddr l)))
	 (doc-misc (append '(!concat) doc-preamble (list doc-body)))
         (post-begin "")
         (pre-end    ""))

    (if (not has-preamble?)
      (begin
        (receive
          (tm-style-options tm-uses tm-init tm-preamble)
          (latex-preamble doc-misc style lan init)
          (output-verbatim "\\documentclass")
          (output-verbatim tm-style-options)
          (output-verbatim "{" (if (nlist? style) style (cAr style)) "}\n")
          (cond ((== lan "korean")
                 (output-verbatim "\\usepackage{hangul}\n"))
                ((in? lan '("chinese" "taiwanese" "japanese"))
                 (with opt (cond ((== lan "japanese")  "{min}")
                                 ((== lan "taiwanese") "{bsmi}")
                                 ((== lan "chinese")   "{gbsn}"))
                   (set! post-begin (string-append "\\begin{CJK*}{UTF8}" opt "\n"))
                   (set! pre-end "\n\\end{CJK*}")
                   (output-verbatim "\\usepackage{CJK}\n")))
                (else
                  (output-verbatim "\\usepackage[" lan "]{babel}\n")
                  (if tmtex-use-unicode?
                    (output-verbatim "\\usepackage[utf8]{inputenc}\n"))))
          (output-verbatim tm-uses)
          (if (string-occurs? "makeidx" (latex-use-package-command doc-body))
            (output-verbatim "\\makeindex"))
          (output-verbatim tm-init)

          (if (!= tm-preamble "")
            (begin
              (output-lf)
              (output-verbatim "%%%%%%%%%% Start TeXmacs macros\n")
              (output-verbatim tm-preamble)
              (output-verbatim "%%%%%%%%%% End TeXmacs macros\n")))
          (if (nnull? doc-preamble)
            (begin
              (output-lf)
              (map-in-order (lambda (x) (texout x) (output-lf)) doc-preamble))))

        (output-lf)
        (output-tex "\\begin{document}")
        (output-lf)
        (output-tex post-begin)
        (output-lf)))
    (texout doc-body)
    (if (not has-end?)
      (begin
        (output-lf)
        (output-tex pre-end)
        (output-lf)
        (output-tex "\\end{document}")
        (output-lf)))))

(define (texout-usepackage x)
  (output-verbatim "\\usepackage{" x "}\n"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Outputting main flow
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (texout-document l)
  (if (nnull? l)
      (begin
	(texout (car l))
	(if (nnull? (cdr l))
	    (begin
	      (output-lf)
	      (output-lf)))
	(texout-document (cdr l)))))

(define (texout-paragraph l)
  (if (nnull? l)
      (begin
	(texout (car l))
	(if (nnull? (cdr l)) (output-lf))
	(texout-paragraph (cdr l)))))

(define (texout-table l)
  (if (nnull? l)
      (begin
	(if (func? (car l) '!row)
	    (begin
	      (texout-row* (cdar l))
	      (if (nnull? (cdr l))
		  (begin
		    (output-tex "\\\\")
		    (output-lf))))
	    (begin
	      (texout (car l))
	      (if (nnull? (cdr l)) (output-lf))))
	(texout-table (cdr l)))))

(define (texout-row l)
  (if (nnull? l)
      (begin
	(texout (car l))
	(if (nnull? (cdr l)) (output-tex " & "))
	(texout-row (cdr l)))))

(define (texout-row* l)
  ;; Dirty hack to avoid [ strings at start of a row
  ;; because of confusion with optional argument of \\
  (if (and (pair? l) (string? (car l)) (string-starts? (car l) "["))
      (set! l `((!concat (!group "") ,(car l)) ,@(cdr l))))
  (if (and (pair? l) (func? (car l) '!concat)
	   (string? (cadar l)) (string-starts? (cadar l) "["))
      (set! l `((!concat (!group "") ,@(cdar l)) ,@(cdr l))))
  (texout-row l))

(define (texout-want-space x1 x2) ;; spacing rules
  (and (not (or (in? x1 '("(" "[" ({) (nobreak)))
		(in? x2 '("," ")" "]" (}) (nobreak)))
		(== x1 " ") (== x2 " ")
		(func? x2 '!nextline)
		(== x2 "'") (func? x2 '!sub) (func? x2 '!sup)
		(func? x1 '&) (func? x2 '&)
		(func? x1 '!nbsp) (func? x2 '!nbsp)
		(func? x1 '!nbhyph) (func? x2 '!nbhyph)
		(and (== x1 "'") (nlist? x2))))
       (or (in? x1 '("," ";" ":"))
	   (func? x1 'tmop) (func? x2 'tmop)
	   (func? x1 '!symbol) (func? x2 '!symbol)
           (and (list-1? x1) (symbol? (car x1))
                (string-alpha? (symbol->string (car x1)))
                (string? x2) (> (string-length x2) 0))
	   (and (nlist? x1) (nlist? x2)))))

(define (texout-concat l)
  (when (nnull? l)
    (texout (car l))
    (if (nnull? (cdr l))
	(texout-concat (if (texout-want-space (car l) (cadr l))
			   (cons " " (cdr l))
			   (cdr l))))))

(define (texout-multiline? x)
  (cond ((nlist? x) #f)
        ((in? (car x) '(!begin !nextline !newline !linefeed !eqn !table)) #t)
        ((and (in? (car x) '(!document !paragraph)) (> (length (cdr x)) 1)) #t)
        ((npair? (cdr x)) #f)
        (else (or (texout-multiline? (cadr x))
                  (texout-multiline? `(!concat ,@(cddr x)))))))

(define (texout-indent x)
  (if (texout-multiline? x)
    (begin
      (output-indent 2)
      (output-lf)
      (texout x)
      (output-indent -2)
      (output-lf))
    (texout x)))

(define (texout-unindent x)
  (with old-indent (get-output-indent)
    (set-output-indent 0)
    (texout x)
    (set-output-indent old-indent)))

(define (texout-linefeed)
  (output-lf))

(define (texout-newline)
  (output-lf)
  (output-lf))

(define (texout-nextline)
  (output-tex "\\\\")
  (output-lf))

(define (texout-nbsp)
  (output-tex "~"))

(define (texout-nbhyph)
  (output-tex "\\mbox{-}"))

(define (texout-verb x)
  (cond ((not (string-index x #\|)) (output-verb "\\verb|" x "|"))
	((not (string-index x #\$)) (output-verb "\\verb$" x "$"))
	((not (string-index x #\@)) (output-verb "\\verb@" x "@"))
	((not (string-index x #\!)) (output-verb "\\verb!" x "!"))
	((not (string-index x #\9)) (output-verb "\\verb9" x "9"))
	((not (string-index x #\X)) (output-verb "\\verbX" x "X"))
	(else (output-verb "\\verb�" x "�"))))

(define (texout-verbatim x)
  (output-lf-verbatim "\\begin{alltt}\n" x "\n\\end{alltt}"))

(define (texout-verbatim* x)
  (output-lf-verbatim x))

(define (texout-group x)
  (output-tex "{")
  (texout x)
  (output-tex "}"))

(define (texout-empty? x)
  (cond ((== x "") #t)
	((func? x '!concat) (list-and (map-in-order texout-empty? (cdr x))))
	((func? x '!document 1) (texout-empty? (cadr x)))
	(else #f)))

(define (texout-double-math? x)
  (or (and (match? x '((:or !document !concat) :%1))
	   (texout-double-math? (cadr x)))
      (and (match? x '((!begin :%1) :%1))
	   (in? (cadar x) '("eqnarray" "eqnarray*" "leqnarray*")))))

(define (texout-math x)
  (cond ((texout-empty? x) (noop))
	((texout-double-math? x) (texout x))
	((match? x '((!begin "center") :%1))
	 (texout `((!begin "equation") ,(cadr x))))
	((and (output-test-end? "$") (not (output-test-end? "\\$")))
	 (output-remove 1)
	 (output-tex " ")
	 (texout x)
	 (output-tex "$"))
	(else
	 (output-tex "$")
	 (texout x)
	 (output-tex "$"))))

(define (texout-eqn x)
  (output-tex "\\[ ")
  (output-indent 3)
  (texout x)
  (output-indent -3)
  (output-tex " \\]"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Outputting macro applications and environments
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (texout-arg x)
  (output-tex (string-append "#" x)))

(define (texout-args l)
  (if (nnull? l)
      (begin
	(if (and (list? (car l)) (== (caar l) '!option))
	    (begin
	      (output-tex "[")
	      (texout (cadar l))
	      (output-tex "]"))
	    (begin
	      (output-tex "{")
	      (texout (car l))
	      (output-tex "}")))
	(texout-args (cdr l)))))

(define (texout-apply what args)
  (output-tex
    (if (string? what) what (string-append "\\" (symbol->string what))))
  (texout-args args))

(define (texout-begin* what args inside)
  (output-tex (string-append "\\begin{" what "}"))
  (texout-args args)
  (output-lf)
  (texout inside)
  (output-lf)
  (output-tex (string-append "\\end{" what "}")))

(define (texout-begin what args inside)
  (output-tex (string-append "\\begin{" what "}"))
  (texout-args args)
  (output-indent 2)
  (output-lf)
  (texout inside)
  (output-indent -2)
  (output-lf)
  (output-tex (string-append "\\end{" what "}")))

(define (texout-script where l)
  (output-tex where)
  (let ((x (car l)))
    (cond ((and (string? x) (= (string-length x) 1)) (output-tex x))
	  (else (texout-args l)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main output routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (texout x)
  ;; (display* "texout " x "\n")
  (cond ((string? x) (output-tex x))
        ((nlist>0? x) (display* "TeXmacs] bad formated stree:\n" x "\n"))
	((== (car x) '!widechar) (output-tex (symbol->string (cadr x))))
	((== (car x) '!file) (texout-file (cdr x)))
	((== (car x) '!document) (texout-document (cdr x)))
	((== (car x) '!paragraph) (texout-paragraph (cdr x)))
	((== (car x) '!table) (texout-table (cdr x)))
	((== (car x) '!concat) (texout-concat (cdr x)))
	((== (car x) '!append) (for-each texout (cdr x)))
	((== (car x) '!symbol) (texout (cadr x)))
	((== (car x) '!linefeed) (texout-linefeed))
	((== (car x) '!indent) (texout-indent (cadr x)))
	((== (car x) '!unindent) (texout-unindent (cadr x)))
	((== (car x) '!newline) (texout-newline))
	((== (car x) '!nextline) (texout-nextline))
	((== (car x) '!nbsp) (texout-nbsp))
	((== (car x) '!nbhyph) (texout-nbhyph))
	((== (car x) '!verb) (texout-verb (cadr x)))
	((== (car x) '!verbatim) (texout-verbatim (cadr x)))
	((== (car x) '!verbatim*) (texout-verbatim* (cadr x)))
	((== (car x) '!arg) (texout-arg (cadr x)))
	((== (car x) '!group) (texout-group (cons '!append (cdr x))))
	((== (car x) '!math) (texout-math (cadr x)))
	((== (car x) '!eqn) (texout-eqn (cadr x)))
	((== (car x) '!sub) (texout-script "_" (cdr x)))
	((== (car x) '!sup) (texout-script "^" (cdr x)))
	((and (list? (car x)) (== (caar x) '!begin))
	 (texout-begin (cadar x) (cddar x) (cadr x)))
	((and (list? (car x)) (== (caar x) '!begin*))
	 (texout-begin* (cadar x) (cddar x) (cadr x)))
	(else (texout-apply (car x) (cdr x)))))

(tm-define (serialize-latex x)
  (texout x)
  (output-produce))

