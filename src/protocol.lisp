(in-package #:rag-protocol)

;;; CLOS RAG: chunk → embed (llm-protocol) → upsert / query-store → rerank.
;;; Embeddings are not owned here — pass float vectors or an LLM-BACKEND.

(defclass rag-vector-store () ())
(defclass rag-chunker () ())
(defclass rag-reranker () ())

(defclass rag-pipeline ()
  ((store :initarg :store :accessor rag-pipeline-store :initform nil)
   (embedder :initarg :embedder :accessor rag-pipeline-embedder :initform nil)
   (chunker :initarg :chunker :accessor rag-pipeline-chunker :initform nil)
   (reranker :initarg :reranker :accessor rag-pipeline-reranker :initform nil)
   (sparse-encoder :initarg :sparse-encoder :accessor rag-pipeline-sparse-encoder
                   :initform nil)))

(defun make-rag-pipeline (&key store embedder chunker reranker sparse-encoder)
  (make-instance 'rag-pipeline
                 :store store :embedder embedder
                 :chunker chunker :reranker reranker
                 :sparse-encoder sparse-encoder))

(defvar *rag-store* nil)
(defvar *rag-chunker* nil)
(defvar *rag-reranker* nil)
(defvar *rag-pipeline* nil)

(defun %ensure (value role message)
  (or value
      (restart-case
          (error 'rag-missing-backend :role role :message message)
        (use-value (supplied)
          :report (lambda (s) (format s "Use a supplied ~a" role))
          :interactive (lambda ()
                         (format *query-io* "~a: " role)
                         (force-output *query-io*)
                         (list (read *query-io*)))
          supplied))))

(defun %ensure-store (&optional (store *rag-store*))
  (%ensure store :store "*rag-store* is nil — load rag-backend-memory or pass a store"))

(defun %ensure-chunker (&optional (chunker *rag-chunker*))
  (%ensure chunker :chunker "*rag-chunker* is nil — load rag-backend-text or pass a chunker"))

(defun %ensure-embedder (&optional (embedder llm-protocol:*llm-backend*))
  (%ensure embedder :embedder "no llm-backend — pass :embedder or bind llm-protocol:*llm-backend*"))

(defun %ensure-pipeline (&optional (pipeline *rag-pipeline*))
  (%ensure pipeline :pipeline "*rag-pipeline* is nil — call MAKE-RAG-PIPELINE"))

(defun %as-list (x)
  (cond
    ((null x) nil)
    ((listp x) x)
    (t (list x))))

(defun %as-single-float-vector (vec)
  (let* ((n (length vec))
         (out (make-array n :element-type 'single-float)))
    (loop for i from 0 below n
          do (setf (aref out i) (float (elt vec i) 1f0)))
    out))

(defun cosine-similarity (a b)
  "Cosine similarity of two real sequences. Zero vectors → 0.0."
  (let ((aa (%as-single-float-vector a))
        (bb (%as-single-float-vector b)))
    (unless (= (length aa) (length bb))
      (error 'rag-dimension-mismatch
             :expected (length aa)
             :actual (length bb)
             :message (format nil "expected dim ~d, got ~d" (length aa) (length bb))))
    (let ((na 0f0)
          (nb 0f0)
          (dot 0f0))
      (loop for i from 0 below (length aa)
            for x = (aref aa i)
            for y = (aref bb i)
            do (incf dot (* x y))
               (incf na (* x x))
               (incf nb (* y y)))
      (let ((da (sqrt na))
            (db (sqrt nb)))
        (if (or (< da 1e-12) (< db 1e-12))
            0f0
            (float (/ dot (* da db)) 1f0))))))

(defun query-vector (query)
  "QUERY is a float sequence or RAG-QUERY with :embedding."
  (etypecase query
    (rag-query
     (or (rag-query-embedding query)
         (error 'rag-missing-backend
                :role :embedding
                :message "rag-query has no embedding — retrieve via a pipeline")))
    (vector query)
    (list (coerce query 'vector))))

(defun query-text (query)
  "QUERY is a string or RAG-QUERY with :text. Vector-only → NIL."
  (etypecase query
    (rag-query (rag-query-text query))
    (string query)
    (vector nil)
    (list nil)))

(defgeneric chunk (chunker document &key size overlap)
  (:documentation "Split DOCUMENT (RAG-DOCUMENT or string) into RAG-CHUNKs."))

(defgeneric upsert (store chunks)
  (:documentation "Insert or replace CHUNKS. Each chunk must have an embedding."))

(defgeneric delete-ids (store ids)
  (:documentation "Remove chunks by id. Missing ids signal RAG-NOT-FOUND (CONTINUE skips)."))

(defgeneric query-store (store query &key top-k filter)
  (:documentation "Nearest neighbors. QUERY is a vector, string, or RAG-QUERY (text / embedding / sparse)."))

(defgeneric rerank (reranker query hits &key top-k)
  (:documentation "Reorder HITS. Default = score desc, truncated to TOP-K."))

(defgeneric ingest (pipeline documents &key model dimensions)
  (:documentation "Chunk → embed via llm-protocol:EMBED → UPSERT. → list of chunks."))

(defgeneric retrieve (pipeline query &key top-k model dimensions)
  (:documentation "Embed QUERY → QUERY-STORE → RERANK. → list of RAG-HITs."))

(defmethod chunk :around ((chunker rag-chunker) document &key size overlap)
  ;; call-next-method does not recompute applicable methods. Redispatch after coerce.
  (let ((doc (coerce-document document)))
    (if (eq doc document)
        (call-next-method)
        (chunk chunker doc :size size :overlap overlap))))

(defmethod chunk ((chunker rag-chunker) document &key size overlap)
  (declare (ignore document size overlap))
  (error 'rag-missing-backend
         :role :chunker
         :message (format nil "~a does not implement chunk" (class-of chunker))))

(defmethod chunk ((chunker null) document &key size overlap)
  (chunk (%ensure-chunker) document :size size :overlap overlap))

(defmethod upsert ((store rag-vector-store) chunks)
  (declare (ignore chunks))
  (error 'rag-missing-backend
         :role :store
         :message (format nil "~a does not implement upsert" (class-of store))))

(defmethod upsert ((store null) chunks)
  (upsert (%ensure-store) chunks))

(defmethod delete-ids ((store rag-vector-store) ids)
  (declare (ignore ids))
  (error 'rag-missing-backend
         :role :store
         :message (format nil "~a does not implement delete-ids" (class-of store))))

(defmethod delete-ids ((store null) ids)
  (delete-ids (%ensure-store) ids))

(defmethod query-store ((store rag-vector-store) query &key top-k filter)
  (declare (ignore query top-k filter))
  (error 'rag-missing-backend
         :role :store
         :message (format nil "~a does not implement query-store" (class-of store))))

(defmethod query-store ((store null) query &key top-k filter)
  (query-store (%ensure-store) query :top-k top-k :filter filter))

(defun %truncate-hits (hits top-k)
  (let* ((sorted (sort (copy-list hits) #'> :key #'rag-hit-score))
         (k (or top-k (length sorted)))
         (cut (subseq sorted 0 (min k (length sorted)))))
    (loop for hit in cut for i from 1
          do (setf (rag-hit-rank hit) i))
    cut))

(defmethod rerank ((reranker rag-reranker) query hits &key top-k)
  (declare (ignore query))
  (%truncate-hits hits top-k))

(defmethod rerank ((reranker null) query hits &key top-k)
  (rerank (or *rag-reranker* (make-identity-reranker)) query hits :top-k top-k))

(defclass passthrough-chunker (rag-chunker) ())

(defun make-passthrough-chunker ()
  (make-instance 'passthrough-chunker))

(defmethod chunk ((chunker passthrough-chunker) (document rag-document) &key size overlap)
  (declare (ignore size overlap))
  (list (make-rag-chunk
         :id (format nil "~a:0" (rag-document-id document))
         :document-id (rag-document-id document)
         :text (rag-document-text document)
         :metadata (copy-list (rag-document-metadata document)))))

(defclass identity-reranker (rag-reranker) ())

(defun make-identity-reranker ()
  (make-instance 'identity-reranker))

(defun %embed-chunks (embedder chunks &key model dimensions)
  (when chunks
    (let* ((texts (mapcar #'rag-chunk-text chunks))
           (result (llm-protocol:embed embedder texts
                                      :model model :dimensions dimensions))
           (embs (llm-protocol:llm-embed-result-embeddings result)))
      (unless (= (length embs) (length chunks))
        (error 'rag-error
               :message (format nil "embed returned ~d vectors for ~d chunks"
                                (length embs) (length chunks))))
      (loop for ch in chunks for emb in embs
            do (setf (rag-chunk-embedding ch)
                     (llm-protocol:llm-embedding-vector emb)))))
  chunks)

(defun %encode-chunk-sparse (encoder chunks)
  (when encoder
    (dolist (ch chunks)
      (unless (rag-chunk-sparse ch)
        (setf (rag-chunk-sparse ch) (encode-sparse encoder ch)))))
  chunks)

(defmethod ingest ((pipeline rag-pipeline) documents &key model dimensions)
  (let* ((chunker (or (rag-pipeline-chunker pipeline)
                      (make-passthrough-chunker)))
         (embedder (%ensure-embedder (or (rag-pipeline-embedder pipeline)
                                         llm-protocol:*llm-backend*)))
         (store (%ensure-store (or (rag-pipeline-store pipeline) *rag-store*)))
         (docs (mapcar #'coerce-document (%as-list documents)))
         (chunks (mapcan (lambda (d) (copy-list (chunk chunker d))) docs)))
    (%embed-chunks embedder chunks :model model :dimensions dimensions)
    (%encode-chunk-sparse (or (rag-pipeline-sparse-encoder pipeline) nil) chunks)
    (upsert store chunks)
    chunks))

(defmethod ingest ((pipeline null) documents &key model dimensions)
  (ingest (%ensure-pipeline) documents :model model :dimensions dimensions))

(defun %coerce-query (query top-k)
  (etypecase query
    (rag-query
     (when top-k
       (setf (rag-query-top-k query) top-k))
     query)
    (string (make-rag-query :text query :top-k (or top-k 5)))
    ((or vector list)
     (make-rag-query :embedding (if (listp query) (coerce query 'vector) query)
                     :top-k (or top-k 5)))))

(defmethod retrieve ((pipeline rag-pipeline) query &key top-k model dimensions)
  (let* ((q (%coerce-query query top-k))
         (k (rag-query-top-k q))
         (store (%ensure-store (or (rag-pipeline-store pipeline) *rag-store*)))
         (vec (or (rag-query-embedding q)
                  (let ((text (rag-query-text q)))
                    (unless (and text (plusp (length text)))
                      (error 'rag-error :message "retrieve needs query text or embedding"))
                    (llm-protocol:embed-query
                     (%ensure-embedder (or (rag-pipeline-embedder pipeline)
                                           llm-protocol:*llm-backend*))
                     text :model model :dimensions dimensions)))))
    (setf (rag-query-embedding q) vec)
    (let ((encoder (rag-pipeline-sparse-encoder pipeline)))
      (when (and encoder (null (rag-query-sparse q)) (rag-query-text q))
        (setf (rag-query-sparse q) (encode-sparse encoder (rag-query-text q)))))
    (let ((hits (query-store store q :top-k k :filter (rag-query-filter q)))
          (reranker (or (rag-pipeline-reranker pipeline)
                        *rag-reranker*
                        (make-identity-reranker))))
      (rerank reranker q hits :top-k k))))

(defmethod retrieve ((pipeline null) query &key top-k model dimensions)
  (retrieve (%ensure-pipeline) query :top-k top-k :model model :dimensions dimensions))
