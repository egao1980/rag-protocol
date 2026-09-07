(in-package #:rag-protocol)

(define-condition rag-error (error)
  ((message :initarg :message :reader rag-error-message :initform nil))
  (:report (lambda (c s)
             (format s "rag error~@[: ~a~]" (rag-error-message c)))))

(define-condition rag-missing-backend (rag-error)
  ((role :initarg :role :reader rag-missing-backend-role :initform nil))
  (:report (lambda (c s)
             (format s "rag ~a missing~@[: ~a~]"
                     (or (rag-missing-backend-role c) "backend")
                     (rag-error-message c)))))

(define-condition rag-dimension-mismatch (rag-error)
  ((expected :initarg :expected :reader rag-dimension-mismatch-expected :initform nil)
   (actual :initarg :actual :reader rag-dimension-mismatch-actual :initform nil)
   (id :initarg :id :reader rag-dimension-mismatch-id :initform nil))
  (:report (lambda (c s)
             (format s "rag dimension mismatch~@[ for ~s~]: expected ~a, got ~a~@[: ~a~]"
                     (rag-dimension-mismatch-id c)
                     (rag-dimension-mismatch-expected c)
                     (rag-dimension-mismatch-actual c)
                     (rag-error-message c)))))

(define-condition rag-not-found (rag-error)
  ((ids :initarg :ids :reader rag-not-found-ids :initform nil))
  (:report (lambda (c s)
             (format s "rag ids not found: ~s~@[: ~a~]"
                     (rag-not-found-ids c)
                     (rag-error-message c)))))
