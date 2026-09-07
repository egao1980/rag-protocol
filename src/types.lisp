(in-package #:rag-protocol)

(defparameter *document-id-counter* 0)

(defun %fresh-document-id ()
  (format nil "doc-~d" (incf *document-id-counter*)))

(defclass rag-document ()
  ((id :initarg :id :accessor rag-document-id)
   (text :initarg :text :accessor rag-document-text :initform "")
   (metadata :initarg :metadata :accessor rag-document-metadata :initform nil)))

(defun rag-document-p (x)
  (typep x 'rag-document))

(defun make-rag-document (&key id text metadata)
  (make-instance 'rag-document
                 :id (or id (%fresh-document-id))
                 :text (or text "")
                 :metadata metadata))

(defun coerce-document (x)
  "DOCUMENT or string → RAG-DOCUMENT."
  (etypecase x
    (rag-document x)
    (string (make-rag-document :text x))))

(defclass rag-chunk ()
  ((id :initarg :id :accessor rag-chunk-id)
   (document-id :initarg :document-id :accessor rag-chunk-document-id :initform nil)
   (text :initarg :text :accessor rag-chunk-text :initform "")
   (embedding :initarg :embedding :accessor rag-chunk-embedding :initform nil)
   (sparse :initarg :sparse :accessor rag-chunk-sparse :initform nil)
   (metadata :initarg :metadata :accessor rag-chunk-metadata :initform nil)))

(defun rag-chunk-p (x)
  (typep x 'rag-chunk))

(defun make-rag-chunk (&key id document-id text embedding sparse metadata)
  (make-instance 'rag-chunk
                 :id id
                 :document-id document-id
                 :text (or text "")
                 :embedding embedding
                 :sparse sparse
                 :metadata metadata))

(defclass rag-hit ()
  ((chunk :initarg :chunk :accessor rag-hit-chunk)
   (score :initarg :score :accessor rag-hit-score :initform 0f0)
   (rank :initarg :rank :accessor rag-hit-rank :initform 0)))

(defun rag-hit-p (x)
  (typep x 'rag-hit))

(defun make-rag-hit (&key chunk (score 0f0) (rank 0))
  (make-instance 'rag-hit :chunk chunk :score score :rank rank))

(defclass rag-query ()
  ((text :initarg :text :accessor rag-query-text :initform nil)
   (embedding :initarg :embedding :accessor rag-query-embedding :initform nil)
   (sparse :initarg :sparse :accessor rag-query-sparse :initform nil)
   (top-k :initarg :top-k :accessor rag-query-top-k :initform 5)
   (filter :initarg :filter :accessor rag-query-filter :initform nil)))

(defun rag-query-p (x)
  (typep x 'rag-query))

(defun make-rag-query (&key text embedding sparse (top-k 5) filter)
  (make-instance 'rag-query
                 :text text
                 :embedding embedding
                 :sparse sparse
                 :top-k top-k
                 :filter filter))
