(in-package #:rag-protocol)

;;; Sparse term-weight vectors: alist ((term . single-float) ...).
;;; Neural SPLADE is a backend encode-fn; in-tree encoder is log(1+tf).

(defclass rag-sparse-encoder () ())

(defgeneric encode-sparse (encoder text-or-chunk)
  (:documentation "TEXT or RAG-CHUNK → alist of (term . single-float weight)."))

(defun query-sparse (query)
  "QUERY is a sparse alist or RAG-QUERY with :sparse. Otherwise NIL."
  (cond
    ((typep query 'rag-query) (rag-query-sparse query))
    ((and (listp query) (consp (first query)) (stringp (car (first query))))
     query)
    (t nil)))

(defun %sparse-text (text-or-chunk)
  (etypecase text-or-chunk
    (string text-or-chunk)
    (rag-chunk (rag-chunk-text text-or-chunk))
    (rag-document (rag-document-text text-or-chunk))))

(defun sparse-dot (a b)
  "Inner product of two sparse alists. Missing terms contribute 0."
  (let ((tb (make-hash-table :test 'equal))
        (dot 0f0))
    (dolist (pair b)
      (setf (gethash (car pair) tb) (float (cdr pair) 1f0)))
    (dolist (pair a)
      (let ((w (gethash (car pair) tb)))
        (when w
          (incf dot (* (float (cdr pair) 1f0) w)))))
    dot))

(defun %log1p-tf (tokens)
  (let ((tf (make-hash-table :test 'equal)))
    (dolist (tok tokens)
      (incf (gethash tok tf 0)))
    (let ((out '()))
      (maphash (lambda (term count)
                 (when (and term (plusp (length term)))
                   (push (cons term (float (log (1+ count)) 1f0)) out)))
               tf)
      (nreverse out))))

(defclass simple-sparse-encoder (rag-sparse-encoder)
  ((analyzer :initarg :analyzer :accessor sparse-encoder-analyzer :initform nil)
   (encode-fn :initarg :encode-fn :accessor sparse-encoder-fn :initform nil)))

(defun make-simple-sparse-encoder (&key analyzer encode-fn)
  (make-instance 'simple-sparse-encoder
                 :analyzer analyzer
                 :encode-fn encode-fn))

(defmethod encode-sparse ((encoder rag-sparse-encoder) text-or-chunk)
  (declare (ignore text-or-chunk))
  (error 'rag-missing-backend
         :role :sparse-encoder
         :message (format nil "~a does not implement encode-sparse"
                          (class-of encoder))))

(defmethod encode-sparse ((encoder simple-sparse-encoder) text-or-chunk)
  (let ((text (%sparse-text text-or-chunk)))
    (if (sparse-encoder-fn encoder)
        (funcall (sparse-encoder-fn encoder) text)
        (%log1p-tf (analyze (or (sparse-encoder-analyzer encoder)
                                (make-simple-analyzer))
                            text)))))

(defmethod encode-sparse ((encoder null) text-or-chunk)
  (encode-sparse (make-simple-sparse-encoder) text-or-chunk))
