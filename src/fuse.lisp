(in-package #:rag-protocol)

;;; Fusion role: merge several hit lists. In-tree RRF and weighted linear.

(defclass rag-fusion () ())

(defgeneric fuse (fusion hit-lists &key top-k)
  (:documentation "Merge HIT-LISTS (list of list of RAG-HIT) → ranked hits."))

(defun %hit-id (hit)
  (rag-chunk-id (rag-hit-chunk hit)))

(defun rrf-fuse (hit-lists &key (k 60) top-k)
  "Reciprocal rank fusion. Earlier lists win chunk identity on id collision."
  (let ((scores (make-hash-table :test 'equal))
        (chunks (make-hash-table :test 'equal)))
    (dolist (hits hit-lists)
      (loop for hit in hits
            for rank from 1
            for chunk = (rag-hit-chunk hit)
            for id = (rag-chunk-id chunk)
            do (unless (gethash id chunks)
                 (setf (gethash id chunks) chunk))
               (incf (gethash id scores 0f0)
                     (float (/ 1d0 (+ k rank)) 1f0))))
    (let ((hits (loop for id being the hash-keys of scores
                      using (hash-value score)
                      collect (make-rag-hit
                               :chunk (gethash id chunks)
                               :score score))))
      (%truncate-hits hits (or top-k (hash-table-count scores))))))

(defun %minmax-norm (score min max)
  (if (< min max)
      (float (/ (- score min) (- max min)) 1f0)
      1f0))

(defun linear-fuse (hit-lists &key weights top-k)
  "Min-max normalize each list, then weighted sum. NIL weights → equal 1/n."
  (let* ((lists (remove nil hit-lists))
         (n (length lists))
         (ws (or weights
                 (make-list n :initial-element (if (plusp n) (/ 1d0 n) 1d0))))
         (scores (make-hash-table :test 'equal))
         (chunks (make-hash-table :test 'equal)))
    (loop for hits in lists
          for w-raw in ws
          for w = (float w-raw 1d0)
          do (let ((nums (mapcar #'rag-hit-score hits)))
               (when nums
                 (let ((mn (reduce #'min nums))
                       (mx (reduce #'max nums)))
                   (dolist (hit hits)
                     (let* ((chunk (rag-hit-chunk hit))
                            (id (rag-chunk-id chunk)))
                       (unless (gethash id chunks)
                         (setf (gethash id chunks) chunk))
                       (incf (gethash id scores 0f0)
                             (float (* w (%minmax-norm (rag-hit-score hit) mn mx))
                                    1f0))))))))
    (let ((hits (loop for id being the hash-keys of scores
                      using (hash-value score)
                      collect (make-rag-hit
                               :chunk (gethash id chunks)
                               :score score))))
      (%truncate-hits hits (or top-k (hash-table-count scores))))))

(defclass rrf-fusion (rag-fusion)
  ((k :initarg :k :accessor rrf-fusion-k :initform 60)))

(defun make-rrf-fusion (&key (k 60))
  (make-instance 'rrf-fusion :k k))

(defclass linear-fusion (rag-fusion)
  ((weights :initarg :weights :accessor linear-fusion-weights :initform nil)))

(defun make-linear-fusion (&key weights)
  (make-instance 'linear-fusion :weights weights))

(defvar *rag-fusion* nil)

(defmethod fuse ((fusion rag-fusion) hit-lists &key top-k)
  (declare (ignore hit-lists top-k))
  (error 'rag-missing-backend
         :role :fusion
         :message (format nil "~a does not implement fuse" (class-of fusion))))

(defmethod fuse ((fusion rrf-fusion) hit-lists &key top-k)
  (rrf-fuse (remove nil hit-lists) :k (rrf-fusion-k fusion) :top-k top-k))

(defmethod fuse ((fusion linear-fusion) hit-lists &key top-k)
  (linear-fuse (remove nil hit-lists)
               :weights (linear-fusion-weights fusion)
               :top-k top-k))

(defmethod fuse ((fusion null) hit-lists &key top-k)
  (fuse (or *rag-fusion* (make-rrf-fusion)) hit-lists :top-k top-k))
