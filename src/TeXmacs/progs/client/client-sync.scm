
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : client-sync.scm
;; DESCRIPTION : synchronizing client files with the server
;; COPYRIGHT   : (C) 2015  Joris van der Hoeven
;;
;; This software falls under the GNU general public license version 3 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (client client-sync)
  (:use (client client-tmfs)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Build list of files to be synchronized
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (dont-sync? u)
  (with last (url->string (url-tail u))
    (or (string-starts? last ".")
        (string-starts? last "#")
        (string-starts? last "svn-")
        (string-ends? last "~")
        (string-ends? last ".aux")
        (string-ends? last ".bak")
        (string-ends? last ".bbl")
        (string-ends? last ".blg")
        (string-ends? last ".log")
        (string-ends? last ".tmp"))))

(tm-define (client-sync-list u)
  (set! u (url->url u))
  (cond ((dont-sync? u) (list))
        ((not (url-exists? u)) (list))
        ((not (url-directory? u)) (list (list #f u)))
        (else
          (let* ((dirl (url-append u (url-wildcard "*")))
                 (l (url->list (url-expand (url-complete dirl "r")))))
            (cons (list #t u)
                  (append-map client-sync-list l))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Merge with list of remote files to be synchronized
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (url-subtract u base)
  (if (== u base)
      (string->url ".")
      (url-delta (url-append base "dummy") u)))

(define (first-string-leq? l1 l2)
  (and (pair? l1) (pair? l2)
       (string<=? (car l1) (car l2))))

(define (compute-sync-list local-base remote-base cont)
  ;;(display* "compute-sync-list " local-base ", " remote-base "\n")
  (let* ((rbase (remote-file-name remote-base))
         (server-name (tmfs-car rbase))
         (server (client-find-server server-name))
         (local-l (client-sync-list local-base))
         (t (make-ahash-table)))
    (client-remote-eval server `(remote-sync-list ,rbase)
      (lambda (remote-l)
        ;;(for (x remote-l)
	;;(display* "Got " x "\n"))
        (for (local-e local-l)
          (with (dir? name) local-e
            (with d (url->string (url-subtract name local-base))
              (ahash-set! t d (list dir? #t #f)))))
        (for (remote-e remote-l)
          (with (dir? name id) remote-e
            (let* ((base (tmfs-cdr (remote-file-name remote-base)))
                   (d (url->string (url-subtract name base)))
                   (prev (ahash-ref t d)))
              (if (not prev)
                  (ahash-set! t d (list dir? #f id))
                  (ahash-set! t d (list dir? (cadr prev) id))))))
        (with l (sort (ahash-table->list t) first-string-leq?)
          ;;(for (x l)
	  ;;(display* "Intermediate: " x "\n"))
          (cont l))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Determine local files which have to be uploaded
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (get-url-sync-info dir? local-exists? local-name remote-name)
  (with-database (user-database "sync")
    (let* ((ids (db-search `(("name" ,(url->system local-name))
                             ("remote-name" ,(url->system remote-name))
                             ("type" "sync"))))
           (date (and local-exists?
                      (number->string (url-last-modified local-name)))))
      (if (nnull? ids)
          (let* ((local-id (car ids))
                 (date* (db-get-field-first local-id "date" #f))
                 (remote-id* (db-get-field-first local-id "remote-id" #f)))
            (list dir? local-name local-id date date* remote-id*))
          (with local-id
              (db-create-entry `(("type" "sync")
                                 ("name" ,(url->system local-name))
                                 ("remote-name" ,(url->system remote-name))
                                 ,@(if date `(("date" ,date)) `())))
            (list dir? local-name local-id date #f #f))))))

(define (get-sync-status info remote-name remote-id)
  (with (dir? local-name local-id date date* remote-id*) info
    ;;(display* "Sync status: " dir? ", " local-name ", " local-id
    ;;          "; " date* " -> " date
    ;;          "; " remote-name ", " remote-id* " -> " remote-id "\n")
    (let* ((local-info (list (url->system local-name) local-id))
           (remote-info (list (url->system remote-name) remote-id))
           (all-info (append (list dir?) local-info remote-info)))
    (cond ((and date remote-id (== date date*) (== remote-id remote-id*)) #f)
          ((and dir? date date* remote-id remote-id*) #f)
          ((and date (== date date*) remote-id* (not remote-id))
           (cons "local-delete" all-info))
          ((and date* (not date) remote-id (== remote-id remote-id*))
           (cons "remote-delete" all-info))
          ((and (!= remote-id remote-id*) (== date date*))
           (cons "download" all-info))
          ((and (!= date date*) (== remote-id remote-id*))
           (cons "upload" all-info))
          (else (cons "conflict" all-info))))))

(define (url-append* base u)
  (if (== (url->url u) (string->url ".")) base (url-append base u)))

(define (prepend-file-dir dir? name)
  (cond ((not name) u)
        (dir? (string->url (string-append "tmfs://remote-dir/" name)))
        (else (string->url (string-append "tmfs://remote-file/" name)))))

(define (file-dir-correct dir? u)
  (prepend-file-dir dir? (remote-file-name u)))

(tm-define (client-sync-status local-base remote-base cont)
  (compute-sync-list local-base remote-base
    (lambda (l)
      (with r (list)
        (for (x l)
          (with (rname dir? local? remote-id) x
            (let* ((local-name (url-append* local-base rname))
                   (remote-name-pre (url-append* remote-base rname))
                   (remote-name (file-dir-correct dir? remote-name-pre))
                   (info (get-url-sync-info dir? local? local-name remote-name))
                   (next (get-sync-status info remote-name remote-id)))
              (when next (set! r (cons next r))))))
        (cont (reverse r))))))

(tm-define (sync-test-old)
  (client-sync-status (string->url "~/test/sync-test") (current-buffer)
    (lambda (l)
      (display* "----- result -----\n")
      (for (x l)
        (display* x "\n")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Transmitting the bulk data
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (filter-status-list l which)
  (list-filter l (lambda (line) (== (car line) which))))

(define (status-line->server line)
  (with sname (tmfs-car (remote-file-name (fifth line)))
    (client-find-server sname)))

(define (append-doc line)
  (with (cmd dir? local-name local-id remote-name remote-id*) line
    (with doc (if dir? "" (string-load (system->url local-name)))
      (rcons line doc))))

(define (post-upload line uploaded)
  ;;(display* "post-upload " line ", " uploaded "\n")
  (and uploaded
       (with-database (user-database "sync")
         (with (cmd dir? local-name local-id remote-name remote-id* doc) line
           (with remote-id uploaded
             (let* ((u (system->url local-name))
                    (date (number->string (url-last-modified u)))
                    (sync-date (number->string (current-time))))
               (db-set-field local-id "remote-id" (list remote-id))
               (db-set-field local-id "date" (list date))
               (db-set-field local-id "sync-date" (list sync-date))
               #t))))))

(define (client-upload uploads* msg cont)
  (if (null? uploads*) (cont #t)
      (with uploads (map append-doc uploads*)
        (with server (status-line->server (car uploads))
          (client-remote-eval server `(remote-upload ,uploads ,msg)
            (lambda (r)
              (when (and (list? r) (== (length r) (length uploads)))
                (with success? (list-and (map post-upload uploads r))
                  (cont success?)))))))))

(define (post-download line downloaded)
  ;;(display* "post-download " line ", " downloaded "\n")
  (and downloaded
       (with-database (user-database "sync")
         (with (cmd dir? local-name local-id remote-name remote-id*) line
           (with (remote-id doc) downloaded
             (with u (system->url local-name)
               (if dir?
                   (when (not (url-exists? u))
                     (system-mkdir u))
                   (string-save doc u))
               (let* ((date (number->string (url-last-modified u)))
                      (sync-date (number->string (current-time))))
                 (db-set-field local-id "remote-id" (list remote-id))
                 (db-set-field local-id "date" (list date))
                 (db-set-field local-id "sync-date" (list sync-date))
                 #t)))))))

(define (client-download downloads cont)
  (if (null? downloads) (cont #t)
      (with server (status-line->server (car downloads))
        (client-remote-eval server `(remote-download ,downloads)
          (lambda (r)
            (when (and (list? r) (== (length r) (length downloads)))
              (with success? (list-and (map post-download downloads r))
                (cont success?))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Master routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (client-sync-proceed l msg cont)
  (client-upload (filter-status-list l "upload") msg
    (lambda (upload-ok?)
      ;;(display* "Uploading done " upload-ok? "\n")
      (client-download (filter-status-list l "download")
        (lambda (download-ok?)
          ;;(display* "Downloading done " download-ok? "\n")
          (cont))))))

(tm-define (remote-upload local-name remote-name msg)
  (client-sync-status local-name remote-name
    (lambda (l)
      (client-upload (append (filter-status-list l "upload")
			     (filter-status-list l "conflict"))
		     msg ignore))))

(tm-define (remote-download local-name remote-name)
  (client-sync-status local-name remote-name
    (lambda (l)
      (client-download (append (filter-status-list l "download")
                               (filter-status-list l "conflict"))
                       ignore))))
