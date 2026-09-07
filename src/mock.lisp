(in-package #:rag-protocol)

;;; In-tree brute-force cosine store for protocol tests. Product store:
;;; rag-backend-memory.

(defclass mock-vector-store (rag-vector-store)
  ((chunks :initform (make-hash-table :test 'equal) :accessor mock-store-table)
   (dimension :initarg :dimension :accessor mock-store-dimension :initform nil)))

(defun make-mock-vector-store (&key dimension)
  (make-instance 'mock-vector-store :dimension dimension))

(defun use-mock-vector-store (&rest args &key &allow-other-keys)
  (setf *rag-store* (apply #'make-mock-vector-store args)))

(defun %accepted-embedding (store chunk)
  (let ((emb (rag-chunk-embedding chunk)))
    (unless (and emb (plusp (length emb)))
      (error 'rag-error
             :message (format nil "chunk ~s has no embedding" (rag-chunk-id chunk))))
    (tagbody
     :retry
       (let ((dim (length emb)))
         (cond
           ((null (mock-store-dimension store))
            (setf (mock-store-dimension store) dim)
            (return-from %accepted-embedding emb))
           ((= dim (mock-store-dimension store))
            (return-from %accepted-embedding emb))
           (t
            (restart-case
                (error 'rag-dimension-mismatch
                       :expected (mock-store-dimension store)
                       :actual dim
                       :id (rag-chunk-id chunk)
                       :message (format nil "chunk ~s: expected dim ~d, got ~d"
                                        (rag-chunk-id chunk)
                                        (mock-store-dimension store)
                                        dim))
              (continue ()
                :report "Skip this chunk"
                (return-from %accepted-embedding nil))
              (use-value (value)
                :report "Use a supplied embedding vector"
                (setf emb value
                      (rag-chunk-embedding chunk) value)
                (go :retry)))))))))

(defmethod upsert ((store mock-vector-store) chunks)
  (dolist (ch (%as-list chunks))
    (when (%accepted-embedding store ch)
      (unless (rag-chunk-id ch)
        (error 'rag-error :message "chunk id required for upsert"))
      (setf (gethash (rag-chunk-id ch) (mock-store-table store)) ch)))
  store)

(defmethod delete-ids ((store mock-vector-store) ids)
  (let* ((ids (%as-list ids))
         (missing '())
         (deleted '()))
    (dolist (id ids)
      (if (nth-value 1 (gethash id (mock-store-table store)))
          (progn
            (remhash id (mock-store-table store))
            (push id deleted))
          (push id missing)))
    (setf missing (nreverse missing)
          deleted (nreverse deleted))
    (when missing
      (restart-case
          (error 'rag-not-found
                 :ids missing
                 :message (format nil "unknown chunk ids: ~s" missing))
        (continue ()
          :report "Skip missing ids"
          (return-from delete-ids deleted))
        (use-value (value)
          :report "Return a supplied value"
          (return-from delete-ids value))))
    deleted))

(defmethod query-store ((store mock-vector-store) query &key top-k filter)
  (let ((vec (query-vector query))
        (hits '()))
    (when (and (mock-store-dimension store)
               (/= (length vec) (mock-store-dimension store)))
      (error 'rag-dimension-mismatch
             :expected (mock-store-dimension store)
             :actual (length vec)
             :message (format nil "query dim ~d, store dim ~d"
                              (length vec) (mock-store-dimension store))))
    (maphash (lambda (id chunk)
               (declare (ignore id))
               (when (or (null filter) (funcall filter chunk))
                 (push (make-rag-hit
                        :chunk chunk
                        :score (cosine-similarity vec (rag-chunk-embedding chunk)))
                       hits)))
             (mock-store-table store))
    (%truncate-hits hits (or top-k 5))))
